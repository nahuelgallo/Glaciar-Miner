extends Node

# State global de la run actual. Autoload — accesible como `RunState` desde
# cualquier script.
#
# Contiene:
#   - HP del jugador (§6.6)
#   - bolsa de minerales (§7.2 / §7.5)
#   - WorldState con tiles, enemigos, rocas, shrines (persiste entre escenas)
#   - handoff de combate (qué enemigos enfrentar, victoria/derrota del último combate)
#
# Pendiente:
#   - héroes persistentes con HP entre combates (§6.4)
#   - signature hero designado (§7.7)
#   - layer / chunk actual (§4)
#   - inventario de McGuffins (§5.3)

const STARTING_HP: int = 30  # §6.6

signal player_hp_changed(current: int, maximum: int)
signal minerals_changed(faction: int, new_amount: int)
signal run_reset()

var player_hp: int = STARTING_HP
var player_max_hp: int = STARTING_HP
var minerals: MineralBag

# Mazo del jugador — hoy es el pool completo del JSON, cacheado. Cuando
# entren deck/discard piles formales (M2), esto se reemplaza por la lista
# real de cartas del mazo activo.
var deck: Array[CardData] = []

# Signature hero (§7.7): id de la carta HERO designada como líder. Se
# auto-invoca al inicio de cada combate sin consumir el cap de invocación.
# Vacío = sin líder designado (fallback: primer hero del pool).
var signature_card_id: StringName = &""

# Roster de héroes "vivos" en la run, mapped por card.id. Cada hero mantiene
# su HP entre combates (§6.4: "Heroes persist between combats at their
# current HP"). Cuando un hero muere (HP=0), queda en el roster pero no se
# puede re-invocar hasta que sea curado en un shrine (open question §6.4
# resolved as "needs healing").
var roster: Dictionary = {}  # StringName -> HeroInstance

# Cuando el signature hero muere durante un combate, este flag fuerza al
# jugador a re-designar uno antes de seguir explorando (§7.7).
var must_redesignate_signature: bool = false

# Mundo persistente — se inicializa en el primer reset_run() o en el primer
# acceso desde la escena de exploración.
var world: WorldState

# Handoff exploración → combate. Cuando se chocan enemigos en exploración,
# acá se anota cuál (o cuáles) se enfrentan, y la escena de combate los
# spawnea al cargar.
var pending_combat_enemy_ids: Array[int] = []

# Handoff combate → exploración. La escena de combate setea esto al terminar;
# exploración lo lee al cargar y aplica las consecuencias.
enum CombatOutcome { NONE, VICTORY, DEFEAT, ABORTED }
var last_combat_outcome: CombatOutcome = CombatOutcome.NONE


func _ready() -> void:
	minerals = MineralBag.new()


func ensure_world() -> WorldState:
	if world == null:
		world = WorldState.new()
	return world


func ensure_deck() -> Array[CardData]:
	if deck.is_empty():
		deck = _ensure_all_cards_pool().duplicate()
	return deck


# Pool master de todas las cartas posibles del juego (lo que existe en el JSON).
# El deck del jugador es un subset/multiset de este pool.
var _all_cards_cache: Array[CardData] = []
func _ensure_all_cards_pool() -> Array[CardData]:
	if _all_cards_cache.is_empty():
		_all_cards_cache = CardLoader.load_all()
	return _all_cards_cache


# Suma N cartas random del pool master al deck (reemplaza al modelo "deck =
# todas las del JSON inmutable"). Devuelve la lista de cartas agregadas para
# que el caller pueda mostrarlas en UI.
func add_random_cards_to_deck(count: int, hero_chance: float = 0.25) -> Array[CardData]:
	var pool := _ensure_all_cards_pool()
	var added: Array[CardData] = []
	if pool.is_empty():
		return added
	# Separamos heroes de otros para poder controlar la proporción.
	var heroes: Array[CardData] = []
	var others: Array[CardData] = []
	for c in pool:
		if c.type == CardData.Type.HERO:
			heroes.append(c)
		else:
			others.append(c)
	for i in count:
		var card: CardData
		if not heroes.is_empty() and randf() < hero_chance:
			card = heroes.pick_random()
		elif not others.is_empty():
			card = others.pick_random()
		else:
			card = pool.pick_random()
		ensure_deck().append(card)
		added.append(card)
	return added


func set_signature(card_id: StringName) -> void:
	signature_card_id = card_id


func get_signature_card() -> CardData:
	if signature_card_id == &"":
		return null
	for c in ensure_deck():
		if c.id == signature_card_id and c.type == CardData.Type.HERO:
			return c
	return null


func reset_run() -> void:
	player_hp = STARTING_HP
	player_max_hp = STARTING_HP
	minerals = MineralBag.new()
	world = WorldState.new()
	deck.clear()
	roster.clear()
	signature_card_id = &""
	must_redesignate_signature = false
	pending_combat_enemy_ids.clear()
	last_combat_outcome = CombatOutcome.NONE
	run_reset.emit()
	player_hp_changed.emit(player_hp, player_max_hp)
	for f in CardData.Faction.values():
		if f == CardData.Faction.NONE:
			continue
		minerals_changed.emit(f, 0)


# Devuelve la HeroInstance persistente para esta carta. Si no existe en el
# roster, la crea fresh (HP completo). Si ya existe, devuelve la misma
# instancia con su HP actual (§6.4 carryover).
func get_or_create_hero(card: CardData) -> HeroInstance:
	if roster.has(card.id):
		return roster[card.id]
	var hero := HeroInstance.new(card)
	roster[card.id] = hero
	return hero


# Cura todos los héroes del roster a HP completo (placeholder: cuando entre
# la opción de heal heroes en shrine, se invoca por hero individual).
func heal_all_heroes() -> void:
	for hero in roster.values():
		var h: HeroInstance = hero
		h.hp = h.max_hp
		h.hp_changed.emit(h.hp, h.max_hp)


func gain_minerals(faction: CardData.Faction, amount: int) -> void:
	if amount <= 0 or faction == CardData.Faction.NONE:
		return
	minerals.gain(faction, amount)
	minerals_changed.emit(faction, minerals.get_amount(faction))


func try_spend_minerals(faction: CardData.Faction, amount: int) -> bool:
	if not minerals.try_spend(faction, amount):
		return false
	minerals_changed.emit(faction, minerals.get_amount(faction))
	return true


# Daño al HP global de la run. Se invoca desde combate cuando un hit de enemigo
# excede la defensa del héroe (§6.4: el overflow va al jugador), o cuando no
# hay héroes en campo y los enemigos atacan al jugador a 2× (§6.5).
func damage_player(amount: int) -> void:
	if amount <= 0:
		return
	player_hp = maxi(0, player_hp - amount)
	player_hp_changed.emit(player_hp, player_max_hp)


# Curación, gateada por max HP. Los Outsiders pueden bajar el max permanente
# (e.g. carta Peter Thiel §7.2.6); por eso el max es mutable.
func heal_player(amount: int) -> void:
	if amount <= 0:
		return
	player_hp = mini(player_max_hp, player_hp + amount)
	player_hp_changed.emit(player_hp, player_max_hp)


func is_dead() -> bool:
	return player_hp <= 0
