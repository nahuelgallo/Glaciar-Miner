class_name Battlefield
extends Node2D

# Campo de combate. Layout §6.1 + mockup de pulido: dos columnas verticales,
# héroes a la izquierda y enemigos a la derecha. 3 slots por columna.
#
# Multi-hero (§6.4): permite hasta 3 héroes simultáneos en el campo. Cuando
# se invoca un nuevo HERO, ocupa el primer slot vacío. Si los 3 están llenos,
# la invocación falla.

const HERO_SLOT_X: float = -540.0
const ENEMY_SLOT_X: float = 540.0
const SLOT_Y_TOP: float = -115.0
const SLOT_Y_SPACING: float = 110.0
const MAX_HEROES: int = 3
const MAX_ENEMIES: int = 3

var _enemies: Array[EnemyInstance] = []
var _enemy_views: Array[EnemyView] = []
var _heroes: Array[HeroInstance] = []
var _hero_views: Array[HeroFieldView] = []


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


# Área general del battlefield (zona del centro entre las dos columnas).
# Drops sobre esta zona son válidos para cartas que no requieren target.
func is_over_battlefield(world_pos: Vector2) -> bool:
	var center_left: float = global_position.x + HERO_SLOT_X + HeroFieldView.W * 0.5 + 20.0
	var center_right: float = global_position.x + ENEMY_SLOT_X - EnemyView.W * 0.5 - 20.0
	var top: float = global_position.y + SLOT_Y_TOP - HeroFieldView.H * 0.5
	var bottom: float = global_position.y + SLOT_Y_TOP + SLOT_Y_SPACING * float(MAX_HEROES - 1) + HeroFieldView.H * 0.5
	var rect := Rect2(
		Vector2(center_left, top),
		Vector2(center_right - center_left, bottom - top)
	)
	return rect.has_point(world_pos)


# ──────────────────────────────────────────────────────────────────
# LAYOUT INTERNO
# ──────────────────────────────────────────────────────────────────


func _relayout_enemies() -> void:
	for i in _enemy_views.size():
		_enemy_views[i].position = Vector2(ENEMY_SLOT_X, SLOT_Y_TOP + SLOT_Y_SPACING * float(i))


func _relayout_heroes() -> void:
	for i in _hero_views.size():
		_hero_views[i].position = Vector2(HERO_SLOT_X, SLOT_Y_TOP + SLOT_Y_SPACING * float(i))


# Outlines de slots vacíos para que el jugador vea dónde puede invocar /
# dónde podría aparecer un nuevo enemigo. Se dibuja antes que los views
# (los views son hijos y se renderizan después).
func _draw() -> void:
	for i in range(_heroes.size(), MAX_HEROES):
		var pos := Vector2(HERO_SLOT_X, SLOT_Y_TOP + SLOT_Y_SPACING * float(i))
		_draw_empty_slot(pos, HeroFieldView.W, HeroFieldView.H)
	for i in range(_enemies.size(), MAX_ENEMIES):
		var pos := Vector2(ENEMY_SLOT_X, SLOT_Y_TOP + SLOT_Y_SPACING * float(i))
		_draw_empty_slot(pos, EnemyView.W, EnemyView.H)


func _draw_empty_slot(center: Vector2, w: float, h: float) -> void:
	var rect := Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h))
	draw_rect(rect, Color(0.13, 0.15, 0.18, 0.8))
	draw_rect(rect, Color(0.30, 0.32, 0.36), false, 1.5)
