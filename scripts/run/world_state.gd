class_name WorldState
extends RefCounted

# Estado persistente del dungeon entre escenas. Vive dentro de RunState para
# que cuando exploration → combat → exploration el mapa quede intacto: el
# enemigo derrotado desaparece, las rocas minadas siguen rotas, los shrines
# usados siguen ahí.
#
# Hoy es una sola "capa" hardcoded. Cuando entren chunks + spaghetti caves
# (§5.5), `_generate_default()` se reemplaza por un generador real.

const W: int = 16
const H: int = 11

const TILE_FLOOR: int = 0
const TILE_WALL: int = 1

# Drop table de rocas (§5.2). Suma 1.0.
const ROCK_DROP_NOTHING_P: float = 0.45
const ROCK_DROP_MINERAL_P: float = 0.40
# El restante es health.

# tiles[x][y] -> int
var tiles: Array = []
var player: Vector2i = Vector2i(2, 5)
# Cada enemigo: { id: int, pos: Vector2i, kind: String, faction: int, hp: int, max_hp: int, intent: int }
var enemies: Array = []
# Cada roca: { pos: Vector2i, hardness: int, max_hardness: int, faction: int }
var rocks: Array = []
# Shrines: lista de Vector2i
var shrines: Array = []

var _next_enemy_id: int = 0


func _init() -> void:
	_generate_default()


func _generate_default() -> void:
	tiles.clear()
	for x in W:
		var col: Array = []
		col.resize(H)
		col.fill(TILE_FLOOR)
		tiles.append(col)

	# Paredes en zigzag para crear corredores. Reemplazable cuando entre §5.5.
	for y in range(2, 8):
		tiles[6][y] = TILE_WALL
	for y in range(4, 10):
		tiles[10][y] = TILE_WALL
	for x in range(3, 6):
		tiles[x][2] = TILE_WALL
	for x in range(8, 13):
		tiles[x][9] = TILE_WALL

	enemies.clear()
	rocks.clear()
	shrines.clear()
	_next_enemy_id = 0
	player = Vector2i(2, 5)

	# Enemigos. Faction define qué mineral dropean al morir (§6.7).
	_add_enemy(Vector2i(11, 5), "Slime", CardData.Faction.APOLITICAL)
	_add_enemy(Vector2i(13, 7), "Slime Outsider", CardData.Faction.OUTSIDER)
	_add_enemy(Vector2i(8, 8), "Slime", CardData.Faction.APOLITICAL)

	# Rocas con dureza 1 (capa 1, §5.2). Faction define el mineral del drop.
	_add_rock(Vector2i(4, 4), 1, CardData.Faction.APOLITICAL)
	_add_rock(Vector2i(4, 6), 1, CardData.Faction.APOLITICAL)
	_add_rock(Vector2i(8, 3), 1, CardData.Faction.PERONIST)
	_add_rock(Vector2i(12, 4), 1, CardData.Faction.LIBERTARIAN)
	_add_rock(Vector2i(2, 8), 1, CardData.Faction.MACRIST)
	_add_rock(Vector2i(13, 2), 1, CardData.Faction.LEFTIST)

	# Shrine (§7.5). Por ahora hay uno solo.
	shrines.append(Vector2i(14, 9))


func _add_enemy(pos: Vector2i, kind: String, faction: int) -> int:
	var id := _next_enemy_id
	_next_enemy_id += 1
	enemies.append({
		"id": id,
		"pos": pos,
		"kind": kind,
		"faction": faction,
		"hp": 12,
		"max_hp": 12,
		"intent": 4,
	})
	return id


func _add_rock(pos: Vector2i, hardness: int, faction: int) -> void:
	rocks.append({
		"pos": pos,
		"hardness": hardness,
		"max_hardness": hardness,
		"faction": faction,
	})


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


func is_blocked_for_movement(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= W or pos.y < 0 or pos.y >= H:
		return true
	if tiles[pos.x][pos.y] == TILE_WALL:
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


# Aplica un hit a la roca y devuelve dict con resultado:
#   { hit: true, broken: bool, drop: Dictionary }
# El drop está vacío si broken=false. Si broken=true puede ser:
#   { kind: "nothing" }
#   { kind: "mineral", faction: int, amount: int }
#   { kind: "health", amount: int }
func mine_rock_at(pos: Vector2i) -> Dictionary:
	var rock := rock_at(pos)
	if rock.is_empty():
		return { "hit": false }
	rock["hardness"] -= 1
	if rock["hardness"] > 0:
		return { "hit": true, "broken": false, "drop": {} }
	# Romper.
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
