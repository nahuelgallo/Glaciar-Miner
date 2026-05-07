class_name EffectExecutor
extends RefCounted

# Vocabulario composable de efectos (§9). Mantengamos esta lista chica:
# cuando una carta tiente a agregar un kind nuevo, primero pensar si se puede
# expresar con los kinds existentes (disciplina del §7.2).
#
# Soportados:
#   deal_damage     {amount} → necesita target enemy
#   heal_player     {amount} → no necesita target específico
#   heal_self       {amount} → necesita hero activo (carrier)
#   gain_minerals   {faction, amount} → no necesita target específico
#
# Pendientes (por dependencia):
#   draw_cards      → necesita deck/discard (§6.2)
#   skip_enemy_turn → necesita ciclo de turnos (§6.2)
#   buff/debuff     → necesita state efímero de combate

# Qué tipo de target necesita una carta para ejecutarse. Lo usa main.gd para
# validar el drop antes de invocar execute().
enum TargetKind { NONE, ENEMY, HERO_SELF }


static func target_kind_for(card: CardData) -> TargetKind:
	if card.type == CardData.Type.HERO:
		return TargetKind.NONE  # se invoca al battlefield, sin target específico
	var kind: String = String(card.effect.get("kind", ""))
	match kind:
		"deal_damage":
			return TargetKind.ENEMY
		"heal_self":
			return TargetKind.HERO_SELF
	return TargetKind.NONE


# Ejecuta la carta dado el contexto. Devuelve { ok: bool, message: String }.
# Context keys posibles:
#   target_enemy     → EnemyInstance
#   active_hero      → HeroInstance
#   summon_callback  → Callable(HeroInstance) usado cuando se invoca un HERO
static func execute(card: CardData, context: Dictionary) -> Dictionary:
	if card.type == CardData.Type.HERO:
		return _summon(card, context)
	var kind: String = String(card.effect.get("kind", ""))
	match kind:
		"deal_damage":
			return _deal_damage(card, context)
		"heal_player":
			return _heal_player(card, context)
		"heal_self":
			return _heal_self(card, context)
		"gain_minerals":
			return _gain_minerals(card, context)
	return { "ok": false, "message": "Carta sin efecto definido" }


static func _summon(card: CardData, context: Dictionary) -> Dictionary:
	var cb: Callable = context.get("summon_callback", Callable())
	if not cb.is_valid():
		return { "ok": false, "message": "Sin handler de invocación" }
	# El callback recibe la CardData y decide cómo construir la instancia
	# (puede reusar la del roster persistente §6.4). Devuelve bool: false
	# significa rechazo (campo lleno o hero a 0 HP, etc.).
	var summoned: bool = cb.call(card)
	if not summoned:
		return { "ok": false, "message": "No se pudo invocar (campo lleno o héroe a 0 HP)" }
	return { "ok": true, "message": "Invocaste a %s" % card.card_name }


static func _deal_damage(card: CardData, context: Dictionary) -> Dictionary:
	var enemy: EnemyInstance = context.get("target_enemy")
	if enemy == null or not enemy.is_alive():
		return { "ok": false, "message": "Necesitás soltar la carta sobre un enemigo" }
	var amount: int = int(card.effect.get("amount", 0))
	# §7.3: faction synergy. Si la carta se juega "a través de" un héroe de
	# la misma facción (carrier), los números potenciados se multiplican
	# por 1.5×. Hoy todos los amounts de deal_damage se consideran ★.
	var synergy := false
	var carrier: HeroInstance = context.get("carrier_hero")
	if carrier != null and carrier.is_alive() and card.faction != CardData.Faction.NONE:
		if carrier.data.faction == card.faction:
			amount = int(float(amount) * 1.5)
			synergy = true
	var result := CombatResolver.resolve_player_attack(enemy, amount)
	var msg := "%s → %s recibe %d" % [card.card_name, enemy.enemy_name, int(result["enemy_damage"])]
	if synergy:
		msg += "  ★ sinergia (%s)" % carrier.data.card_name
	return { "ok": true, "message": msg }


static func _heal_player(card: CardData, _context: Dictionary) -> Dictionary:
	var amount: int = int(card.effect.get("amount", 0))
	if amount <= 0:
		return { "ok": false, "message": "Cantidad inválida" }
	RunState.heal_player(amount)
	return { "ok": true, "message": "%s → +%d HP del jugador" % [card.card_name, amount] }


static func _heal_self(card: CardData, context: Dictionary) -> Dictionary:
	var hero: HeroInstance = context.get("active_hero")
	if hero == null or not hero.is_alive():
		return { "ok": false, "message": "Necesitás un héroe en el campo" }
	var amount: int = int(card.effect.get("amount", 0))
	hero.heal(amount)
	return { "ok": true, "message": "%s → %s +%d HP" % [card.card_name, hero.data.card_name, amount] }


static func _gain_minerals(card: CardData, _context: Dictionary) -> Dictionary:
	var amount: int = int(card.effect.get("amount", 0))
	if amount <= 0:
		return { "ok": false, "message": "Cantidad inválida" }
	var faction_str: String = String(card.effect.get("faction", "APOLITICAL")).to_upper()
	var faction: int = CardData.Faction.get(faction_str, CardData.Faction.APOLITICAL)
	if faction == CardData.Faction.NONE:
		faction = CardData.Faction.APOLITICAL
	RunState.gain_minerals(faction, amount)
	return {
		"ok": true,
		"message": "%s → +%d %s" % [card.card_name, amount, MineralBag.mineral_name(faction)],
	}
