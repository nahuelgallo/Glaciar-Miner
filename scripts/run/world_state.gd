class_name WorldState
extends RefCounted

# Estado persistente del dungeon entre escenas. Vive dentro de RunState para
# que cuando exploration → combat → exploration el mapa quede intacto: el
# enemigo derrotado desaparece, las rocas minadas siguen rotas, los shrines
# usados siguen ahí.
#
# Soporta múltiples capas (§4): generate_for_layer(n) regenera el world.
# Layer 1 → enemigos básicos, rocas hardness 1. Layer N → enemigos más
# fuertes, rocas hardness ≤ N, boss más duro. Hard gate (§5.3) bloquea
# el camino a la siguiente capa hasta que el jugador tenga el McGuffin
# que dropea el boss (§6.8).

const W: int = 16
const H: int = 11

const TILE_FLOOR: int = 0
const TILE_WALL: int = 1
const TILE_HARD_GATE: int = 2

# Drop table de rocas (§5.2). Suma 1.0.
const ROCK_DROP_NOTHING_P: float = 0.45
const ROCK_DROP_MINERAL_P: float = 0.40
# El restante es health.

const MAX_LAYERS: int = 3

# tiles[x][y] -> int
var tiles: Array = []
var player: Vector2i = Vector2i(2, 5)
# Cada enemigo: { id, pos, kind, faction, hp, max_hp, intent, is_boss, group_size }
var enemies: Array = []
# Cada roca: { pos, hardness, max_hardness, faction }
var rocks: Array = []
# Shrines: lista de Vector2i
var shrines: Array = []
# Posición del hard gate (Vector2i(-1,-1) si la capa no tiene gate, o sea capa final)
var hard_gate_pos: Vector2i = Vector2i(-1, -1)

var layer: int = 1
var _next_enemy_id: int = 0


func _init() -> void:
	generate_for_layer(1)


func generate_for_layer(n: int) -> void:
	layer = clampi(n, 1, MAX_LAYERS)
	tiles.clear()
	for x in W:
		var col: Array = []
		col.resize(H)
		col.fill(TILE_FLOOR)
		tiles.append(col)

	# Paredes en zigzag distintas por capa para que se note visualmente.
	match layer:
		1:
			for y in range(2, 8):
				tiles[6][y] = TILE_WALL
			for y in range(4, 10):
				tiles[10][y] = TILE_WALL
			for x in range(3, 6):
				tiles[x][2] = TILE_WALL
			for x in range(8, 13):
				tiles[x][9] = TILE_WALL
		2:
			for x in range(2, 14):
				tiles[x][4] = TILE_WALL
			tiles[7][4] = TILE_FLOOR  # paso central
			for y in range(5, 9):
				tiles[3][y] = TILE_WALL
			for y in range(6, 10):
				tiles[12][y] = TILE_WALL
		_:
			# Layer 3+: laberinto más enredado
			for y in range(1, 9):
				if y % 2 == 1:
					tiles[5][y] = TILE_WALL
					tiles[10][y] = TILE_WALL
			for x in range(4, 12):
				tiles[x][5] = TILE_WALL
			tiles[8][5] = TILE_FLOOR

	enemies.clear()
	rocks.clear()
	shrines.clear()
	hard_gate_pos = Vector2i(-1, -1)
	_next_enemy_id = 0
	player = Vector2i(2, 5)

	# Enemigos comunes (escalan con layer)
	var enemy_pool := [
		{"pos": Vector2i(11, 5), "kind": "Slime", "faction": CardData.Faction.APOLITICAL},
		{"pos": Vector2i(13, 7), "kind": "Slime Outsider", "faction": CardData.Faction.OUTSIDER},
		{"pos": Vector2i(8, 8), "kind": "Slime", "faction": CardData.Faction.APOLITICAL},
	]
	if layer >= 2:
		enemy_pool.append({"pos": Vector2i(14, 3), "kind": "Slime Macrista", "faction": CardData.Faction.MACRIST})
	if layer >= 3:
		enemy_pool.append({"pos": Vector2i(7, 2), "kind": "Slime Libertario", "faction": CardData.Faction.LIBERTARIAN})

	var base_hp := 10 + layer * 2
	var base_intent := 3 + layer
	for entry in enemy_pool:
		var pos: Vector2i = entry["pos"]
		# Mover si choca con paredes hardcoded de la capa
		if tiles[pos.x][pos.y] == TILE_WALL:
			continue
		_add_enemy(pos, String(entry["kind"]), int(entry["faction"]), base_hp, base_intent, false)

	# Boss en una posición fija del mapa (esquina opuesta al player)
	var boss_pos := Vector2i(W - 2, H - 2)
	if tiles[boss_pos.x][boss_pos.y] == TILE_WALL:
		boss_pos = Vector2i(W - 3, H - 3)
	# Limpiar el bloque around boss para asegurar acceso
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var p := boss_pos + Vector2i(dx, dy)
			if p.x >= 0 and p.x < W and p.y >= 0 and p.y < H:
				tiles[p.x][p.y] = TILE_FLOOR
	_add_enemy(boss_pos, "BOSS Capa %d" % layer, CardData.Faction.OUTSIDER,
		int(base_hp * 2.5), int(base_intent * 1.5), true)

	# Rocas con dureza ≤ layer
	var rock_positions := [
		Vector2i(4, 4), Vector2i(4, 6), Vector2i(8, 3),
		Vector2i(12, 4), Vector2i(2, 8), Vector2i(13, 2),
	]
	if layer >= 2:
		rock_positions.append(Vector2i(5, 7))
		rock_positions.append(Vector2i(11, 6))
	var rock_factions := [
		CardData.Faction.APOLITICAL, CardData.Faction.APOLITICAL,
		CardData.Faction.PERONIST, CardData.Faction.LIBERTARIAN,
		CardData.Faction.MACRIST, CardData.Faction.LEFTIST,
		CardData.Faction.PERONIST, CardData.Faction.OUTSIDER,
	]
	for i in rock_positions.size():
		var pos: Vector2i = rock_positions[i]
		if tiles[pos.x][pos.y] == TILE_WALL:
			continue
		# Skip si choca con un enemigo
		if _find_enemy_at(pos) >= 0:
			continue
		var hardness := 1 + (randi() % layer)
		_add_rock(pos, hardness, int(rock_factions[i % rock_factions.size()]))

	# Shrine
	var shrine_pos := Vector2i(14, 9) if layer == 1 else Vector2i(2, 9)
	if tiles[shrine_pos.x][shrine_pos.y] != TILE_WALL:
		shrines.append(shrine_pos)

	# Hard gate (§5.3) — bloquea el paso a la siguiente capa. Solo si NO es
	# la última capa (en la última, derrotar al boss = victoria).
	if layer < MAX_LAYERS:
		var gate_pos := Vector2i(W - 1, H / 2)
		while tiles[gate_pos.x][gate_pos.y] == TILE_WALL and gate_pos.y > 0:
			gate_pos.y -= 1
		tiles[gate_pos.x][gate_pos.y] = TILE_HARD_GATE
		hard_gate_pos = gate_pos


func _add_enemy(pos: Vector2i, kind: String, faction: int, max_hp: int, intent: int, is_boss: bool) -> int:
	var id := _next_enemy_id
	_next_enemy_id += 1
	enemies.append({
		"id": id,
		"pos": pos,
		"kind": kind,
		"faction": faction,
		"hp": max_hp,
		"max_hp": max_hp,
		"intent": intent,
		"is_boss": is_boss,
	})
	return id


func _add_rock(pos: Vector2i, hardness: int, faction: int) -> void:
	rocks.append({
		"pos": pos,
		"hardness": hardness,
		"max_hardness": hardness,
		"faction": faction,
	})


func _find_enemy_at(pos: Vector2i) -> int:
	for i in enemies.size():
		if enemies[i]["pos"] == pos:
			return i
	return -1


func enemy_at(pos: Vector2i) -> Dictionary:
	for e in enemies:
		if e["pos"] == pos:
			return e
	return {}


func rock_at(pos: Vector2i) -> Dictionary:
	for r in rocks:
		if r["pos"] == pos:
			return r
	return {}


func is_shrine_at(pos: Vector2i) -> bool:
	return shrines.has(pos)


func is_hard_gate_at(pos: Vector2i) -> bool:
	return pos == hard_gate_pos and pos != Vector2i(-1, -1)


# is_blocked_for_movement: el hard gate cuenta como pared salvo que el
# llamador indique que tiene McGuffin (cosa que sabe RunState).
func is_blocked_for_movement(pos: Vector2i, can_open_gate: bool = false) -> bool:
	if pos.x < 0 or pos.x >= W or pos.y < 0 or pos.y >= H:
		return true
	var t := tiles[pos.x][pos.y]
	if t == TILE_WALL:
		return true
	if t == TILE_HARD_GATE and not can_open_gate:
		return true
	if not rock_at(pos).is_empty():
		return true
	return false


func remove_enemy_by_id(id: int) -> void:
	for i in enemies.size():
		if enemies[i]["id"] == id:
			enemies.remove_at(i)
			return


func remove_rock_at(pos: Vector2i) -> void:
	for i in rocks.size():
		if rocks[i]["pos"] == pos:
			rocks.remove_at(i)
			return


func open_hard_gate() -> void:
	if hard_gate_pos == Vector2i(-1, -1):
		return
	tiles[hard_gate_pos.x][hard_gate_pos.y] = TILE_FLOOR
	hard_gate_pos = Vector2i(-1, -1)


# Aplica un hit a la roca y devuelve dict con resultado:
#   { hit: true, broken: bool, drop: Dictionary }
func mine_rock_at(pos: Vector2i) -> Dictionary:
	var rock := rock_at(pos)
	if rock.is_empty():
		return { "hit": false }
	rock["hardness"] -= 1
	if rock["hardness"] > 0:
		return { "hit": true, "broken": false, "drop": {} }
	var rock_faction: int = int(rock["faction"])
	remove_rock_at(pos)
	return { "hit": true, "broken": true, "drop": _roll_drop(rock_faction) }


func _roll_drop(rock_faction: int) -> Dictionary:
	var roll := randf()
	if roll < ROCK_DROP_NOTHING_P:
		return { "kind": "nothing" }
	if roll < ROCK_DROP_NOTHING_P + ROCK_DROP_MINERAL_P:
		return {
			"kind": "mineral",
			"faction": rock_faction,
			"amount": 1 + randi() % 2,
		}
	return { "kind": "health", "amount": 2 + randi() % 3 }
