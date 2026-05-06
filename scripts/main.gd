extends Node2D

@onready var _hand: HandManager = $HandManager
@onready var _help_label: Label = $Help

var _pool: Array[CardData] = []
var _battlefield: Battlefield
var _discard_pile: DiscardPileView
var _hp_label: Label
var _hero_label: Label
var _last_attack_label: Label
var _turn_label: Label
var _mineral_labels: Dictionary = {}  # Faction -> Label

# §6.2: turnos del jugador alternan con turnos enemigos. Mano persiste, no se
# descarta al fin del turno. Cap de mano implícito para que no crezca infinito.
const HAND_CAP: int = 7
const ENEMY_INTENT_MIN: int = 3
const ENEMY_INTENT_MAX: int = 7
var _turn_number: int = 1

# Cuando el combate termina (victoria o derrota), bloqueamos más acciones
# para que el jugador se concentre en apretar Q y volver a exploración.
var _combat_ended: bool = false

# Héroe "activo" para validar la regla del §6.4. Cuando exista la mecánica
# real de invocación desde la mano, esto pasa al CombatState.
var _active_hero: HeroInstance

# Ciclo de valores para variar la intención enemiga al testear (atajo I).
const _INTENT_CYCLE: Array[int] = [3, 5, 8, 12]
var _intent_cycle_index: int = 1  # arranca en 5

# Mapeo tecla → facción para los atajos de testeo de gain.
const _MINERAL_HOTKEYS: Dictionary = {
	KEY_1: CardData.Faction.PERONIST,
	KEY_2: CardData.Faction.LIBERTARIAN,
	KEY_3: CardData.Faction.MACRIST,
	KEY_4: CardData.Faction.LEFTIST,
	KEY_5: CardData.Faction.APOLITICAL,
	KEY_6: CardData.Faction.OUTSIDER,
}


func _ready() -> void:
	_setup_picking()

	_pool = CardLoader.load_all()
	if _pool.is_empty():
		push_warning("Main: no hay cartas en el JSON")
	else:
		# Mano inicial de 5 cartas random.
		for i in 5:
			_hand.add_card(_pool.pick_random())
		print("Cargadas %d cartas en la mano" % _hand.size())

	_build_battlefield()
	_build_hud()
	_connect_run_state()
	_summon_first_hero_from_pool()
	_spawn_pending_or_default_enemies()
	_hand.card_dropped.connect(_on_card_dropped)
	_refresh_hud()
	_help_label.text = (
		"Arrastrá una carta al campo:\n"
		+ "  HERO → al battlefield    ACTION daño → al enemigo    EFFECT → al battlefield\n"
		+ "T = End Turn (enemigos atacan, robás 1)   Q = volver a exploración\n"
		+ "SPACE = +carta   BACKSPACE = -carta   R = reset mano\n"
		+ "1..6 = +2 mineral   N = -3 HP   H = +3 HP\n"
		+ "K = enemigo individual ejecuta intención   D = vos pegás 3 al enemigo\n"
		+ "I = ciclar intención   O = quitar/restaurar héroe   E = respawn enemigo"
	)


func _setup_picking() -> void:
	# Sin picking activado, los Area2D de las cartas no reciben mouse_entered
	# ni input_event (Godot 4 lo desactiva por default).
	var vp := get_viewport()
	vp.physics_object_picking = true
	# Cuando dos cartas se solapan, sin first_only ambas reciben el click.
	# sort=true ordena por z-index (la de arriba gana), first_only=true entrega
	# el evento solo a la primera.
	if "physics_object_picking_sort" in vp:
		vp.physics_object_picking_sort = true
	if "physics_object_picking_first_only" in vp:
		vp.physics_object_picking_first_only = true


func _build_battlefield() -> void:
	_battlefield = Battlefield.new()
	_battlefield.name = "Battlefield"
	# Centrado horizontalmente, encima del HandManager (1280×720, hand en y=470).
	_battlefield.position = Vector2(640.0, 250.0)
	add_child(_battlefield)

	_discard_pile = DiscardPileView.new()
	_discard_pile.name = "DiscardPile"
	# A la derecha del battlefield, alineado vertical con el hero slot.
	_discard_pile.position = Vector2(1120.0, 330.0)
	add_child(_discard_pile)


func _build_hud() -> void:
	var hud := Control.new()
	hud.name = "Hud"
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.anchor_right = 1.0
	hud.anchor_bottom = 1.0
	add_child(hud)

	var panel := VBoxContainer.new()
	panel.position = Vector2(16.0, 110.0)
	panel.add_theme_constant_override("separation", 4)
	hud.add_child(panel)

	_turn_label = _make_label(15, Color(0.85, 0.95, 0.55))
	panel.add_child(_turn_label)

	_hp_label = _make_label(16, Color(1.0, 0.55, 0.55))
	panel.add_child(_hp_label)

	_hero_label = _make_label(13, Color(0.95, 0.85, 0.55))
	panel.add_child(_hero_label)

	_last_attack_label = _make_label(12, Color(0.85, 0.85, 0.85))
	_last_attack_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_last_attack_label.custom_minimum_size = Vector2(360.0, 0.0)
	panel.add_child(_last_attack_label)

	# Una label por facción real (NONE no produce mineral propio — §7.3).
	for f in CardData.Faction.values():
		if f == CardData.Faction.NONE:
			continue
		var lbl := _make_label(13, _faction_text_color(f))
		_mineral_labels[f] = lbl
		panel.add_child(lbl)


func _make_label(font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _connect_run_state() -> void:
	RunState.player_hp_changed.connect(_on_player_hp_changed)
	RunState.minerals_changed.connect(_on_minerals_changed)


func _summon_first_hero_from_pool() -> void:
	for card in _pool:
		if card.type == CardData.Type.HERO:
			_set_active_hero(HeroInstance.new(card))
			return


func _set_active_hero(hero: HeroInstance) -> void:
	if _active_hero != null and _active_hero.hp_changed.is_connected(_on_hero_hp_changed):
		_active_hero.hp_changed.disconnect(_on_hero_hp_changed)
	_active_hero = hero
	if _active_hero != null:
		_active_hero.hp_changed.connect(_on_hero_hp_changed)
	if _battlefield != null:
		_battlefield.set_active_hero(hero)
	_refresh_hero_label()


func _spawn_pending_or_default_enemies() -> void:
	if _battlefield == null:
		return
	_battlefield.clear_enemies()
	var spawned := 0
	var ids := RunState.pending_combat_enemy_ids
	if not ids.is_empty():
		var world := RunState.ensure_world()
		for id in ids:
			for enemy_dict in world.enemies:
				if int(enemy_dict["id"]) == id:
					var ei := EnemyInstance.new(
						String(enemy_dict["kind"]),
						int(enemy_dict["max_hp"]),
						int(enemy_dict["intent"])
					)
					_battlefield.add_enemy(ei)
					spawned += 1
					break
	if spawned == 0:
		# Fallback de testing: si la escena se abre directo (sin haber pasado
		# por exploración) o el id no se encontró, spawneá un Slime base.
		_spawn_default_enemy()


func _spawn_default_enemy() -> void:
	if _battlefield == null:
		return
	_battlefield.clear_enemies()
	_battlefield.add_enemy(EnemyInstance.new("Slime", 14, _INTENT_CYCLE[_intent_cycle_index]))


func _refresh_hud() -> void:
	_on_player_hp_changed(RunState.player_hp, RunState.player_max_hp)
	_refresh_hero_label()
	_refresh_turn_label()
	_last_attack_label.text = ""
	for f in _mineral_labels.keys():
		_on_minerals_changed(f, RunState.minerals.get_amount(f))


func _refresh_turn_label() -> void:
	_turn_label.text = "Turno %d (jugador)" % _turn_number


func _refresh_hero_label() -> void:
	if _active_hero == null:
		_hero_label.text = "Sin héroe en el campo (enemigos pegan al jugador a 2×)"
		return
	_hero_label.text = "Héroe: %s — HP %d/%d  DEF %d" % [
		_active_hero.data.card_name,
		_active_hero.hp,
		_active_hero.max_hp,
		_active_hero.defense(),
	]


func _on_player_hp_changed(current: int, maximum: int) -> void:
	_hp_label.text = "HP %d / %d" % [current, maximum]


func _on_hero_hp_changed(_current: int, _maximum: int) -> void:
	_refresh_hero_label()


func _on_minerals_changed(faction: int, new_amount: int) -> void:
	var lbl: Label = _mineral_labels.get(faction)
	if lbl == null:
		return
	lbl.text = "%s: %d" % [MineralBag.mineral_name(faction), new_amount]


func _faction_text_color(f: CardData.Faction) -> Color:
	match f:
		CardData.Faction.PERONIST:    return Color(0.55, 0.78, 0.95)
		CardData.Faction.LIBERTARIAN: return Color(0.78, 0.62, 0.95)
		CardData.Faction.MACRIST:     return Color(0.95, 0.85, 0.35)
		CardData.Faction.LEFTIST:     return Color(0.95, 0.55, 0.55)
		CardData.Faction.APOLITICAL:  return Color(0.85, 0.85, 0.88)
		CardData.Faction.OUTSIDER:    return Color(0.62, 0.58, 0.55)
	return Color.WHITE


func _enemy_executes_intent() -> void:
	if _combat_ended:
		return
	var enemy: EnemyInstance = _battlefield.first_alive_enemy() if _battlefield != null else null
	if enemy == null:
		_last_attack_label.text = "No hay enemigos vivos."
		return
	var result := CombatResolver.resolve_enemy_attack(_active_hero, enemy.intent_damage)
	_report_enemy_attack(enemy, result)
	# §6.4: si el héroe murió en este hit, queda removido del campo. Su carta
	# no se destruye (decay cortado §7.8); cuando exista la mecánica de
	# resummon esto vuelve.
	if result["hero_died"]:
		_set_active_hero(null)
	_check_combat_outcome()


func _player_attacks_enemy(damage: int) -> void:
	if _combat_ended:
		return
	var enemy: EnemyInstance = _battlefield.first_alive_enemy() if _battlefield != null else null
	if enemy == null:
		_last_attack_label.text = "No hay enemigos vivos para atacar."
		return
	var result := CombatResolver.resolve_player_attack(enemy, damage)
	_report_player_attack(enemy, result)
	_check_combat_outcome()


func _report_enemy_attack(enemy: EnemyInstance, result: Dictionary) -> void:
	var incoming: int = result["incoming_damage"]
	if result["target"] == null:
		_last_attack_label.text = "%s pega %d → SIN HÉROE — jugador recibe %d (×2)" % [
			enemy.enemy_name, incoming, result["player_damage"]
		]
		return
	var hero: HeroInstance = result["target"]
	var line := "%s pega %d → %s recibe %d" % [
		enemy.enemy_name, incoming, hero.data.card_name, result["hero_damage"]
	]
	if result["player_damage"] > 0:
		line += "  |  overflow al jugador: %d" % result["player_damage"]
	if result["hero_died"]:
		line += "  |  ✖ héroe caído"
	_last_attack_label.text = line


func _report_player_attack(enemy: EnemyInstance, result: Dictionary) -> void:
	var incoming: int = result["incoming_damage"]
	var actual: int = result["enemy_damage"]
	var line := "Vos pegás %d → %s recibe %d" % [incoming, enemy.enemy_name, actual]
	if result["enemy_died"]:
		line += "  |  ✖ derrotado"
	_last_attack_label.text = line


func _on_card_dropped(card: CardData, drop_position: Vector2, view: CardView) -> void:
	var context := _build_drop_context(card, drop_position)
	if context.is_empty():
		# Drop inválido (target wrong / fuera del battlefield). La carta vuelve
		# sola al slot porque ya soltó el drag.
		_last_attack_label.text = _drop_invalid_message(card)
		return
	if _combat_ended:
		return
	var result := EffectExecutor.execute(card, context)
	_last_attack_label.text = result["message"]
	if result["ok"]:
		# §7.1: action/effect cards van al descarte después de jugarse; HERO
		# cards salen de la mano al invocarse (van al campo, no al discard,
		# pero sin estado de "carta en juego" todavía las apilamos acá igual
		# para feedback visual).
		_hand.remove_view(view)
		if _discard_pile != null:
			_discard_pile.add_card(card)
		_check_combat_outcome()


# Construye el context para EffectExecutor según target_kind y el drop.
# Devuelve {} si el drop no es válido para esta carta.
func _build_drop_context(card: CardData, drop_position: Vector2) -> Dictionary:
	var kind := EffectExecutor.target_kind_for(card)
	# HERO: drop sobre el battlefield → invoca.
	if card.type == CardData.Type.HERO:
		if not _battlefield.is_over_battlefield(drop_position):
			return {}
		return { "summon_callback": Callable(self, "_set_active_hero") }
	match kind:
		EffectExecutor.TargetKind.ENEMY:
			var enemy := _battlefield.enemy_at(drop_position)
			if enemy == null:
				return {}
			return { "target_enemy": enemy }
		EffectExecutor.TargetKind.HERO_SELF:
			if _active_hero == null:
				return {}
			# HERO_SELF: aceptamos drop sobre el hero slot o sobre el área general.
			if not (_battlefield.is_over_hero_slot(drop_position) or _battlefield.is_over_battlefield(drop_position)):
				return {}
			return { "active_hero": _active_hero }
		EffectExecutor.TargetKind.NONE, _:
			if not _battlefield.is_over_battlefield(drop_position):
				return {}
			return {}


func _drop_invalid_message(card: CardData) -> String:
	var kind := EffectExecutor.target_kind_for(card)
	if card.type == CardData.Type.HERO:
		return "Soltá %s sobre el campo de combate para invocar." % card.card_name
	match kind:
		EffectExecutor.TargetKind.ENEMY:
			return "%s necesita un enemigo como target." % card.card_name
		EffectExecutor.TargetKind.HERO_SELF:
			return "%s necesita un héroe activo en el campo." % card.card_name
	return "Soltá %s sobre el campo de combate." % card.card_name


func _end_player_turn() -> void:
	if _battlefield == null or _combat_ended:
		return
	# Cada enemigo vivo ejecuta su intent telegrafiada (§6.5).
	var enemies := _battlefield.enemies()
	var any_acted := false
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		any_acted = true
		var result := CombatResolver.resolve_enemy_attack(_active_hero, enemy.intent_damage)
		_report_enemy_attack(enemy, result)
		if result["hero_died"]:
			_set_active_hero(null)
		_check_combat_outcome()
		if _combat_ended:
			return
	# Recalcular intents para el próximo turno (§6.5: telegrafiadas con
	# anticipación). Random simple por ahora — patrones por enemy type vendrán.
	for enemy in enemies:
		if enemy.is_alive():
			enemy.set_intent(randi_range(ENEMY_INTENT_MIN, ENEMY_INTENT_MAX))
	# Inicio del próximo turno del jugador: draw 1 (§6.2). Cap de mano para
	# que no crezca infinito mientras el deck/discard no exista.
	_turn_number += 1
	_refresh_turn_label()
	if not _pool.is_empty() and _hand.size() < HAND_CAP:
		_hand.add_card(_pool.pick_random())
	if not any_acted:
		_last_attack_label.text = "Sin enemigos vivos. Turno %d." % _turn_number


# Chequea cada vez que el state combate puede haber cambiado: ataque del
# jugador, drop de carta, intent enemigo, end turn.
func _check_combat_outcome() -> void:
	if _combat_ended:
		return
	if RunState.is_dead():
		_trigger_defeat()
		return
	var enemies := _battlefield.enemies()
	if enemies.is_empty():
		return  # escena sin enemigos (modo testing) — no es victoria
	var any_alive := false
	for e in enemies:
		if e.is_alive():
			any_alive = true
			break
	if not any_alive:
		_trigger_victory()


func _trigger_victory() -> void:
	_combat_ended = true
	# Drop de minerales por enemigo derrotado (§6.7). Se mapean por la facción
	# del enemy_dict del world.
	var world := RunState.ensure_world()
	var msg := "VICTORIA. Drops:"
	var any_drop := false
	for id in RunState.pending_combat_enemy_ids:
		for enemy_dict in world.enemies:
			if int(enemy_dict["id"]) == id:
				var f: int = int(enemy_dict["faction"])
				if f != CardData.Faction.NONE:
					var amt := 2 + randi() % 3
					RunState.gain_minerals(f, amt)
					msg += " +%d %s" % [amt, MineralBag.mineral_name(f)]
					any_drop = true
				break
	if not any_drop:
		msg += " (sin minerales)"
	_last_attack_label.text = msg
	_help_label.text = "VICTORIA — apretá Q para volver a explorar"
	RunState.last_combat_outcome = RunState.CombatOutcome.VICTORY


func _trigger_defeat() -> void:
	_combat_ended = true
	_last_attack_label.text = "Te derrotaron."
	_help_label.text = "DERROTADO — apretá Q para reiniciar la run"
	RunState.last_combat_outcome = RunState.CombatOutcome.DEFEAT


func _return_to_exploration() -> void:
	# Si el combate no terminó formalmente, lo abortamos: el enemigo del
	# mundo queda intacto. Si terminó (victoria/derrota), exploration aplica
	# las consecuencias al cargar.
	if not _combat_ended:
		RunState.last_combat_outcome = RunState.CombatOutcome.ABORTED
	get_tree().change_scene_to_file("res://scenes/exploration/exploration.tscn")


func _toggle_active_hero() -> void:
	if _active_hero != null:
		_set_active_hero(null)
		return
	# Restaurar el primer héroe del pool (reinstanciado a HP completo).
	for card in _pool:
		if card.type == CardData.Type.HERO:
			_set_active_hero(HeroInstance.new(card))
			return


func _cycle_enemy_intent() -> void:
	var enemy: EnemyInstance = _battlefield.first_alive_enemy() if _battlefield != null else null
	if enemy == null:
		return
	_intent_cycle_index = (_intent_cycle_index + 1) % _INTENT_CYCLE.size()
	enemy.set_intent(_INTENT_CYCLE[_intent_cycle_index])


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# Mineral hotkeys (1..6).
	if _MINERAL_HOTKEYS.has(event.keycode):
		RunState.gain_minerals(_MINERAL_HOTKEYS[event.keycode], 2)
		return
	match event.keycode:
		KEY_SPACE:
			if not _pool.is_empty():
				_hand.add_card(_pool.pick_random())
		KEY_BACKSPACE:
			if _hand.size() > 0:
				_hand.remove_card(_hand.size() - 1)
		KEY_R:
			while _hand.size() > 0:
				_hand.remove_card(0)
			for i in 5:
				_hand.add_card(_pool.pick_random())
		KEY_N:
			RunState.damage_player(3)
		KEY_H:
			RunState.heal_player(3)
		KEY_K:
			_enemy_executes_intent()
		KEY_D:
			_player_attacks_enemy(3)
		KEY_I:
			_cycle_enemy_intent()
		KEY_O:
			_toggle_active_hero()
		KEY_E:
			_spawn_default_enemy()
		KEY_T:
			_end_player_turn()
		KEY_Q:
			_return_to_exploration()
