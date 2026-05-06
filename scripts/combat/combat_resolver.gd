class_name CombatResolver
extends RefCounted

# Resolución de ataques enemigos. Reglas:
#   §6.4 — Defensa como threshold. Hit ≤ defensa: absorbido por el héroe.
#          Hit > defensa: overflow al héroe Y al jugador.
#   §6.5 — Sin héroe en el campo: el ataque pega al jugador a 2× daño.

# Resultado de un ataque enemigo. No es struct (GDScript no tiene), es un
# diccionario con shape conocido para que la UI / log pueda reportar.
# Keys:
#   target          -> HeroInstance | null
#   incoming_damage -> int (el daño base del ataque, sin multiplicadores)
#   hero_damage     -> int (cuánto se restó al HP del héroe, 0 si no había)
#   player_damage   -> int (cuánto se restó al HP del jugador)
#   hero_died       -> bool (true si el héroe quedó en 0 HP por este hit)


static func resolve_enemy_attack(target: HeroInstance, damage: int) -> Dictionary:
	if damage <= 0:
		return _result(target, damage, 0, 0, false)

	# §6.5: sin héroe en el campo, el jugador recibe 2× directo.
	if target == null or not target.is_alive():
		var doubled := damage * 2
		RunState.damage_player(doubled)
		return _result(null, damage, 0, doubled, false)

	# §6.4: hit ≤ defensa absorbido por el héroe; hit > defensa hace
	# overflow al héroe y al jugador (mismo número).
	var hp_before: int = target.hp
	var overflow: int = target.take_hit(damage)
	var hero_loss: int = hp_before - target.hp
	if overflow > 0:
		RunState.damage_player(overflow)
	return _result(target, damage, hero_loss, overflow, not target.is_alive())


static func _result(
	target: HeroInstance,
	incoming: int,
	hero_loss: int,
	player_loss: int,
	hero_died: bool
) -> Dictionary:
	return {
		"target": target,
		"incoming_damage": incoming,
		"hero_damage": hero_loss,
		"player_damage": player_loss,
		"hero_died": hero_died,
	}


# Daño del jugador (vía cartas action/effect) hacia un enemigo. Daño directo —
# los enemigos no tienen Defensa en el modelo del GDD. Devuelve un dict con
# breakdown análogo a resolve_enemy_attack.
static func resolve_player_attack(target: EnemyInstance, damage: int) -> Dictionary:
	if target == null or not target.is_alive() or damage <= 0:
		return {
			"target": target,
			"incoming_damage": damage,
			"enemy_damage": 0,
			"enemy_died": false,
		}
	var actual := target.take_damage(damage)
	return {
		"target": target,
		"incoming_damage": damage,
		"enemy_damage": actual,
		"enemy_died": not target.is_alive(),
	}
