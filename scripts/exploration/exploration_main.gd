extends Node2D

# Vista cenital del dungeon (§5). Estado persistente vive en RunState.world
# para que exploration ↔ combat preserve el mapa.
#
# Verbos del jugador (§5.1):
#   - moverse a tile vacío
#   - bump enemigo  → entra a combate (§5.4)
#   - bump roca     → minás 1 hit; al romperse dropea según §5.2
#   - bump shrine   → activación automática si podés pagar (§7.5)
#
# Comportamiento del enemigo (§5.4): random walk cada turno. Line-of-sight
# chase llega después.

const TILE_SIZE: int = 40

var _world: WorldState
var _origin: Vector2

var _info_label: Label
var _hp_label: Label
var _last_event_label: Label
var _minerals_label: Label
var _deck_button: Button


func _ready() -> void:
	_world = RunState.ensure_world()
	_handle_combat_outcome()
	# El world puede haber sido reemplazado por un reset en _handle_combat_outcome.
	_world = RunState.ensure_world()

	_origin = Vector2(
		640.0 - WorldState.W * TILE_SIZE * 0.5,
		380.0 - WorldState.H * TILE_SIZE * 0.5
	)
	_build_hud()
	_refresh_hud()
	queue_redraw()


# Aplica el resultado del último combate (si lo hubo) antes de redibujar.
func _handle_combat_outcome() -> void:
	match RunState.last_combat_outcome:
		RunState.CombatOutcome.VICTORY:
			for id in RunState.pending_combat_enemy_ids:
				_world.remove_enemy_by_id(id)
		RunState.CombatOutcome.DEFEAT:
			RunState.reset_run()
		_:
			pass
	RunState.pending_combat_enemy_ids.clear()
	RunState.last_combat_outcome = RunState.CombatOutcome.NONE
	# §7.7: si el líder murió, abrir el menú de mazo en modo forzado para
	# que el jugador elija uno nuevo antes de seguir explorando.
	if RunState.must_redesignate_signature:
		# Esperar un frame para que el árbol esté listo
		call_deferred("_open_deck_menu_forced")


func _open_deck_menu_forced() -> void:
	for child in get_children():
		if child is DeckManagementMenu:
			return
	var menu := DeckManagementMenu.new()
	menu.forced = true
	add_child(menu)


func _build_hud() -> void:
	_info_label = _make_label(14, Color(0.85, 0.95, 0.55))
	_info_label.position = Vector2(16.0, 16.0)
	_info_label.text = "WASD/flechas: moverte · bump enemigo: combate · bump roca: minar · bump shrine: curar · M: abrir mazo"
	add_child(_info_label)

	_hp_label = _make_label(15, Color(1.0, 0.55, 0.55))
	_hp_label.position = Vector2(16.0, 40.0)
	add_child(_hp_label)

	_minerals_label = _make_label(12, Color(0.85, 0.85, 0.88))
	_minerals_label.position = Vector2(16.0, 64.0)
	_minerals_label.custom_minimum_size = Vector2(720.0, 0.0)
	add_child(_minerals_label)

	_last_event_label = _make_label(13, Color(0.95, 0.85, 0.55))
	_last_event_label.position = Vector2(16.0, 88.0)
	_last_event_label.custom_minimum_size = Vector2(900.0, 0.0)
	add_child(_last_event_label)

	_deck_button = Button.new()
	_deck_button.text = "MAZO  (M)"
	_deck_button.position = Vector2(1130.0, 16.0)
	_deck_button.size = Vector2(130.0, 36.0)
	_deck_button.add_theme_font_size_override("font_size", 14)
	_deck_button.pressed.connect(_open_deck_menu)
	add_child(_deck_button)


func _make_label(font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _refresh_hud() -> void:
	_hp_label.text = "HP %d / %d" % [RunState.player_hp, RunState.player_max_hp]
	# Una línea con todos los minerales.
	var parts: Array[String] = []
	for f in CardData.Faction.values():
		if f == CardData.Faction.NONE:
			continue
		var amt := RunState.minerals.get_amount(f)
		if amt > 0:
			parts.append("%s %d" % [MineralBag.mineral_name(f), amt])
	_minerals_label.text = "Minerales: " + (", ".join(parts) if not parts.is_empty() else "—")


func _draw() -> void:
	# Background (ver insight de orden de render: pintar acá adentro).
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.05, 0.06, 0.08))
	# Tiles
	for x in WorldState.W:
		for y in WorldState.H:
			var rect := _tile_rect(Vector2i(x, y))
			var color: Color
			match _world.tiles[x][y]:
				WorldState.TILE_WALL: color = Color(0.42, 0.38, 0.34)
				_:                    color = Color(0.16, 0.18, 0.20)
			draw_rect(rect, color)
			draw_rect(rect, Color(0.10, 0.09, 0.08), false, 1.0)
	# Shrines (§7.5) — verde-azulado con cruz.
	for s in _world.shrines:
		var rect := _tile_rect(s)
		draw_rect(rect, Color(0.30, 0.65, 0.55))
		draw_rect(rect, Color(0.85, 0.95, 0.78), false, 2.0)
		var c := rect.position + rect.size * 0.5
		draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), Color(0.08, 0.06, 0.04), 2.0)
		draw_line(c + Vector2(0, -8), c + Vector2(0, 8), Color(0.08, 0.06, 0.04), 2.0)
	# Rocas (§5.2) — color oscurecido de la facción del mineral que dropean.
	for r in _world.rocks:
		var rect := _tile_rect(r["pos"])
		var color := _faction_color(int(r["faction"])).darkened(0.20)
		draw_rect(rect, color)
		draw_rect(rect, Color(0.08, 0.06, 0.04), false, 2.0)
		# Cruz de gem para que se distingan a primera vista.
		var c := rect.position + rect.size * 0.5
		var s := 6.0
		draw_line(c + Vector2(-s, -s), c + Vector2(s, s), Color(0.10, 0.08, 0.06, 0.85), 2.0)
		draw_line(c + Vector2(s, -s), c + Vector2(-s, s), Color(0.10, 0.08, 0.06, 0.85), 2.0)
	# Enemigos
	for e in _world.enemies:
		var col := _faction_color(int(e["faction"])).blend(Color(0.85, 0.30, 0.30, 0.6))
		_draw_actor(e["pos"], col)
	# Player
	_draw_actor(_world.player, Color(0.40, 0.72, 0.95))


func _faction_color(f: int) -> Color:
	match f:
		CardData.Faction.PERONIST:    return Color(0.55, 0.78, 0.95)
		CardData.Faction.LIBERTARIAN: return Color(0.62, 0.42, 0.85)
		CardData.Faction.MACRIST:     return Color(0.95, 0.85, 0.35)
		CardData.Faction.LEFTIST:     return Color(0.85, 0.30, 0.30)
		CardData.Faction.APOLITICAL:  return Color(0.78, 0.80, 0.82)
		CardData.Faction.OUTSIDER:    return Color(0.28, 0.26, 0.24)
	return Color(0.6, 0.6, 0.6)


func _tile_rect(p: Vector2i) -> Rect2:
	return Rect2(_origin + Vector2(p) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE))


func _draw_actor(grid_pos: Vector2i, color: Color) -> void:
	var inset := 5.0
	var rect := Rect2(
		_origin + Vector2(grid_pos) * TILE_SIZE + Vector2(inset, inset),
		Vector2(TILE_SIZE - inset * 2.0, TILE_SIZE - inset * 2.0)
	)
	draw_rect(rect, color)
	draw_rect(rect, Color(0.08, 0.06, 0.04), false, 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# M = abrir el menú de mazo (designar líder, ver cartas)
	if event.keycode == KEY_M:
		_open_deck_menu()
		return
	var move := Vector2i.ZERO
	match event.keycode:
		KEY_W, KEY_UP:    move = Vector2i(0, -1)
		KEY_S, KEY_DOWN:  move = Vector2i(0, 1)
		KEY_A, KEY_LEFT:  move = Vector2i(-1, 0)
		KEY_D, KEY_RIGHT: move = Vector2i(1, 0)
	if move == Vector2i.ZERO:
		return
	_try_move_player(move)


func _open_deck_menu() -> void:
	# Si ya hay un menú abierto, no abrir otro encima.
	for child in get_children():
		if child is DeckManagementMenu:
			return
	var menu := DeckManagementMenu.new()
	add_child(menu)


func _try_move_player(delta: Vector2i) -> void:
	var target: Vector2i = _world.player + delta
	if target.x < 0 or target.x >= WorldState.W or target.y < 0 or target.y >= WorldState.H:
		return
	if _world.tiles[target.x][target.y] == WorldState.TILE_WALL:
		return
	# Bump enemigo → combate, sin avanzar mundo.
	var enemy_dict := _world.enemy_at(target)
	if not enemy_dict.is_empty():
		_bump_enemy(enemy_dict)
		return
	# Bump roca → minás un hit, no te movés, sí avanza el turno mundial.
	var rock_dict := _world.rock_at(target)
	if not rock_dict.is_empty():
		_mine_rock(target)
		_advance_world_turn()
		_refresh_hud()
		queue_redraw()
		return
	# Floor o shrine: te movés. Si entrás a un shrine desde fuera, se activa.
	var was_on_shrine := _world.is_shrine_at(_world.player)
	var moving_to_shrine := _world.is_shrine_at(target)
	_world.player = target
	if moving_to_shrine and not was_on_shrine:
		_activate_shrine(target)
	_advance_world_turn()
	_refresh_hud()
	queue_redraw()


func _bump_enemy(enemy_dict: Dictionary) -> void:
	RunState.pending_combat_enemy_ids.clear()
	RunState.pending_combat_enemy_ids.append(int(enemy_dict["id"]))
	RunState.last_combat_outcome = RunState.CombatOutcome.NONE
	get_tree().change_scene_to_file("res://scenes/test/card_test.tscn")


func _mine_rock(pos: Vector2i) -> void:
	var result := _world.mine_rock_at(pos)
	if not bool(result.get("hit", false)):
		return
	if not bool(result.get("broken", false)):
		var remaining: int = int(_world.rock_at(pos).get("hardness", 0))
		_last_event_label.text = "Mineás (queda %d)" % remaining
		return
	var drop: Dictionary = result.get("drop", {})
	_last_event_label.text = "Roca rota — %s" % _apply_drop(drop)


func _apply_drop(drop: Dictionary) -> String:
	match drop.get("kind", "nothing"):
		"mineral":
			var f: int = int(drop["faction"])
			var amt: int = int(drop["amount"])
			RunState.gain_minerals(f, amt)
			return "+%d %s" % [amt, MineralBag.mineral_name(f)]
		"health":
			var amt2: int = int(drop["amount"])
			RunState.heal_player(amt2)
			return "+%d HP" % amt2
		_:
			return "(sin drop)"


# §7.5: bump shrine abre el ShrineMenu con opciones (curar / packs).
func _activate_shrine(_pos: Vector2i) -> void:
	# Si ya hay un menú abierto, no abrir otro.
	for child in get_children():
		if child is ShrineMenu:
			return
	var menu := ShrineMenu.new()
	menu.closed.connect(_on_shrine_closed)
	add_child(menu)
	_last_event_label.text = "Shrine abierto. Elegí una opción."


func _on_shrine_closed() -> void:
	_last_event_label.text = "Shrine cerrado."
	_refresh_hud()


func _advance_world_turn() -> void:
	# Iteramos sobre una copia porque _bump_enemy puede cambiar la escena
	# y queremos que la iteración no se corrompa.
	var snapshot := _world.enemies.duplicate()
	for e in snapshot:
		# Si la escena cambió de golpe, no seguimos.
		if not is_inside_tree():
			return
		var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
		dirs.shuffle()
		for d in dirs:
			var target: Vector2i = e["pos"] + d
			if _world.is_blocked_for_movement(target):
				continue
			if _world.is_shrine_at(target):
				continue
			if not _world.enemy_at(target).is_empty():
				continue
			if target == _world.player:
				_bump_enemy(e)
				return
			e["pos"] = target
			break
