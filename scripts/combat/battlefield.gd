class_name Battlefield
extends Node2D

# Campo de combate. Layout §6.1 + mockup de pulido: dos columnas verticales,
# héroes a la izquierda y enemigos a la derecha. 3 slots por columna.
#
# Multi-hero (§6.4): permite hasta 3 héroes simultáneos en el campo. Cuando
# se invoca un nuevo HERO, ocupa el primer slot vacío. Si los 3 están llenos,
# la invocación falla.

const PLAYER_SLOT_X: float = -560.0
const HERO_SLOT_X: float = -380.0
const ENEMY_SLOT_X: float = 540.0
const SLOT_Y_TOP: float = -115.0
const SLOT_Y_SPACING: float = 110.0
const MAX_HEROES: int = 3
const MAX_ENEMIES: int = 3

var _enemies: Array[EnemyInstance] = []
var _enemy_views: Array[EnemyView] = []
var _heroes: Array[HeroInstance] = []
var _hero_views: Array[HeroFieldView] = []
var _player_view: PlayerView

# Highlight de drop targets durante drag de carta. -1 = inactivo.
var _highlight_card_type: int = -1
var _highlight_target_kind: int = -1


func _ready() -> void:
	# El Minero (jugador) siempre está en su columna a la izquierda. Es la
	# representación visual del HP global de la run (§6.6).
	_player_view = PlayerView.new()
	_player_view.position = Vector2(PLAYER_SLOT_X, 0.0)
	add_child(_player_view)


# ──────────────────────────────────────────────────────────────────
# ENEMIGOS
# ──────────────────────────────────────────────────────────────────


func add_enemy(enemy: EnemyInstance) -> bool:
	if _enemies.size() >= MAX_ENEMIES:
		return false
	_enemies.append(enemy)
	var view := EnemyView.new()
	view.data = enemy
	add_child(view)
	_enemy_views.append(view)
	_relayout_enemies()
	queue_redraw()
	return true


func clear_enemies() -> void:
	for v in _enemy_views:
		v.queue_free()
	_enemy_views.clear()
	_enemies.clear()
	queue_redraw()


func first_alive_enemy() -> EnemyInstance:
	for e in _enemies:
		if e.is_alive():
			return e
	return null


func enemies() -> Array[EnemyInstance]:
	return _enemies


# ──────────────────────────────────────────────────────────────────
# HÉROES
# ──────────────────────────────────────────────────────────────────


# Agrega un héroe al primer slot vacío. Devuelve true si pudo invocar.
# Si los 3 slots están llenos, retorna false sin modificar nada.
func add_hero(hero: HeroInstance) -> bool:
	if _heroes.size() >= MAX_HEROES:
		return false
	_heroes.append(hero)
	var view := HeroFieldView.new()
	view.data = hero
	add_child(view)
	_hero_views.append(view)
	_relayout_heroes()
	queue_redraw()
	return true


func clear_heroes() -> void:
	for v in _hero_views:
		v.queue_free()
	_hero_views.clear()
	_heroes.clear()
	queue_redraw()


func remove_dead_heroes() -> int:
	var removed := 0
	var i := _heroes.size() - 1
	while i >= 0:
		if not _heroes[i].is_alive():
			_hero_views[i].queue_free()
			_hero_views.remove_at(i)
			_heroes.remove_at(i)
			removed += 1
		i -= 1
	if removed > 0:
		_relayout_heroes()
		queue_redraw()
	return removed


func first_alive_hero() -> HeroInstance:
	for h in _heroes:
		if h.is_alive():
			return h
	return null


func heroes() -> Array[HeroInstance]:
	return _heroes


func is_full_of_heroes() -> bool:
	return _heroes.size() >= MAX_HEROES


# ──────────────────────────────────────────────────────────────────
# DROP TARGETING
# ──────────────────────────────────────────────────────────────────


func enemy_at(world_pos: Vector2) -> EnemyInstance:
	for i in _enemy_views.size():
		var v: EnemyView = _enemy_views[i]
		var rect := Rect2(
			v.global_position - Vector2(EnemyView.W, EnemyView.H) * 0.5,
			Vector2(EnemyView.W, EnemyView.H)
		)
		if rect.has_point(world_pos) and _enemies[i].is_alive():
			return _enemies[i]
	return null


# True si el drop está sobre algún slot de héroe (vacío o lleno).
func is_over_hero_slot(world_pos: Vector2) -> bool:
	var col_x: float = global_position.x + HERO_SLOT_X
	for i in MAX_HEROES:
		var slot_y: float = global_position.y + SLOT_Y_TOP + SLOT_Y_SPACING * float(i)
		var rect := Rect2(
			Vector2(col_x - HeroFieldView.W * 0.5, slot_y - HeroFieldView.H * 0.5),
			Vector2(HeroFieldView.W, HeroFieldView.H)
		)
		if rect.has_point(world_pos):
			return true
	return false


# Área general del battlefield. Cubre TODO el "campo de juego" según mockup:
# desde la columna de héroes (incluida) hasta la columna de enemigos
# (incluida), verticalmente entre el top bar y el bottom area. Drops
# sobre esta zona son válidos para cartas TargetKind.NONE.
func is_over_battlefield(world_pos: Vector2) -> bool:
	var pad := 30.0
	var left: float = global_position.x + PLAYER_SLOT_X - PlayerView.W * 0.5 - pad
	var right: float = global_position.x + ENEMY_SLOT_X + EnemyView.W * 0.5 + pad
	var top: float = global_position.y + SLOT_Y_TOP - PlayerView.H * 0.5 - pad
	var bottom: float = global_position.y + SLOT_Y_TOP + SLOT_Y_SPACING * float(MAX_HEROES - 1) + PlayerView.H * 0.5 + pad
	var rect := Rect2(Vector2(left, top), Vector2(right - left, bottom - top))
	return rect.has_point(world_pos)


# Lista de positions globales de cada slot (para drag arrow targeting).
func slot_positions_for_drop(card_type: int, target_kind: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if card_type == CardData.Type.HERO:
		# Posiciones de los slots vacíos (los llenos no son target válido).
		for i in range(_heroes.size(), MAX_HEROES):
			positions.append(global_position + Vector2(HERO_SLOT_X, SLOT_Y_TOP + SLOT_Y_SPACING * float(i)))
		return positions
	if target_kind == EffectExecutor.TargetKind.ENEMY:
		# Posiciones de enemigos vivos.
		for i in _enemies.size():
			if _enemies[i].is_alive():
				positions.append(_enemy_views[i].global_position)
		return positions
	# Default: centro del battlefield.
	positions.append(global_position)
	return positions


# ──────────────────────────────────────────────────────────────────
# LAYOUT INTERNO
# ──────────────────────────────────────────────────────────────────


func _relayout_enemies() -> void:
	for i in _enemy_views.size():
		_enemy_views[i].position = Vector2(ENEMY_SLOT_X, SLOT_Y_TOP + SLOT_Y_SPACING * float(i))


func _relayout_heroes() -> void:
	for i in _hero_views.size():
		_hero_views[i].position = Vector2(HERO_SLOT_X, SLOT_Y_TOP + SLOT_Y_SPACING * float(i))


# Outlines de slots vacíos + highlight de drop targets durante el drag.
func _draw() -> void:
	# Highlight overlay para "drop sobre área general" (TargetKind.NONE)
	if _highlight_target_kind == EffectExecutor.TargetKind.NONE and _highlight_card_type != CardData.Type.HERO:
		_draw_battlefield_highlight()
	# Slots vacíos
	for i in range(_heroes.size(), MAX_HEROES):
		var pos := Vector2(HERO_SLOT_X, SLOT_Y_TOP + SLOT_Y_SPACING * float(i))
		_draw_empty_slot(pos, HeroFieldView.W, HeroFieldView.H)
		# HERO arrastrada → resaltar slots de héroe vacíos
		if _highlight_card_type == CardData.Type.HERO:
			_draw_highlight_border(pos, HeroFieldView.W, HeroFieldView.H, Color(0.55, 0.95, 0.65))
	for i in range(_enemies.size(), MAX_ENEMIES):
		var pos := Vector2(ENEMY_SLOT_X, SLOT_Y_TOP + SLOT_Y_SPACING * float(i))
		_draw_empty_slot(pos, EnemyView.W, EnemyView.H)
	# ENEMY target → resaltar enemigos vivos
	if _highlight_target_kind == EffectExecutor.TargetKind.ENEMY:
		for i in _enemies.size():
			if _enemies[i].is_alive():
				var pos := Vector2(ENEMY_SLOT_X, SLOT_Y_TOP + SLOT_Y_SPACING * float(i))
				_draw_highlight_border(pos, EnemyView.W, EnemyView.H, Color(0.95, 0.55, 0.55))
	# HERO_SELF target → resaltar héroes vivos
	if _highlight_target_kind == EffectExecutor.TargetKind.HERO_SELF:
		for i in _heroes.size():
			if _heroes[i].is_alive():
				var pos := Vector2(HERO_SLOT_X, SLOT_Y_TOP + SLOT_Y_SPACING * float(i))
				_draw_highlight_border(pos, HeroFieldView.W, HeroFieldView.H, Color(0.55, 0.95, 0.65))


func _draw_empty_slot(center: Vector2, w: float, h: float) -> void:
	var rect := Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h))
	draw_rect(rect, Color(0.13, 0.15, 0.18, 0.8))
	draw_rect(rect, Color(0.30, 0.32, 0.36), false, 1.5)


func _draw_highlight_border(center: Vector2, w: float, h: float, color: Color) -> void:
	# Border externo grueso para indicar "target válido"
	var pad := 5.0
	var rect := Rect2(center - Vector2(w + pad * 2.0, h + pad * 2.0) * 0.5, Vector2(w + pad * 2.0, h + pad * 2.0))
	draw_rect(rect, color, false, 3.0)


func _draw_battlefield_highlight() -> void:
	# Highlight de TODO el campo de juego (matchea el área del mockup en rosa).
	var pad := 30.0
	var left: float = PLAYER_SLOT_X - PlayerView.W * 0.5 - pad
	var right: float = ENEMY_SLOT_X + EnemyView.W * 0.5 + pad
	var top: float = SLOT_Y_TOP - PlayerView.H * 0.5 - pad
	var bottom: float = SLOT_Y_TOP + SLOT_Y_SPACING * float(MAX_HEROES - 1) + PlayerView.H * 0.5 + pad
	var rect := Rect2(Vector2(left, top), Vector2(right - left, bottom - top))
	draw_rect(rect, Color(0.55, 0.95, 0.65, 0.10))
	draw_rect(rect, Color(0.55, 0.95, 0.65, 0.6), false, 2.0)


func set_drop_highlight(card_type: int, target_kind: int) -> void:
	_highlight_card_type = card_type
	_highlight_target_kind = target_kind
	queue_redraw()


func clear_drop_highlight() -> void:
	_highlight_card_type = -1
	_highlight_target_kind = -1
	queue_redraw()
