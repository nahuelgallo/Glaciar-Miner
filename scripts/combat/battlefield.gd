class_name Battlefield
extends Node2D

# Campo de combate. Layout §6.1: enemigos arriba, héroes abajo. Por ahora
# soporta múltiples enemigos en línea horizontal y un único hero slot
# (cuando el GDD habilite múltiples héroes en el campo, se generaliza igual
# que la fila de enemigos).

const ENEMY_SLOT_Y: float = -100.0
const HERO_SLOT_Y: float = 80.0
const ENEMY_SPACING: float = 170.0
# Margen extra al área "general" del battlefield para drops sin target
# específico (cartas heal_player, gain_minerals, invocaciones).
const DROP_AREA_MARGIN_X: float = 320.0
const DROP_AREA_MARGIN_TOP: float = 180.0
const DROP_AREA_MARGIN_BOTTOM: float = 160.0

var _enemies: Array[EnemyInstance] = []
var _enemy_views: Array[EnemyView] = []
var _active_hero: HeroInstance
var _hero_view: HeroFieldView


func add_enemy(enemy: EnemyInstance) -> void:
	_enemies.append(enemy)
	var view := EnemyView.new()
	view.data = enemy
	add_child(view)
	_enemy_views.append(view)
	_relayout_enemies()


func clear_enemies() -> void:
	for v in _enemy_views:
		v.queue_free()
	_enemy_views.clear()
	_enemies.clear()


func first_alive_enemy() -> EnemyInstance:
	for e in _enemies:
		if e.is_alive():
			return e
	return null


func enemies() -> Array[EnemyInstance]:
	return _enemies


func set_active_hero(hero: HeroInstance) -> void:
	if _hero_view != null:
		_hero_view.queue_free()
		_hero_view = null
	_active_hero = hero
	if hero != null:
		_hero_view = HeroFieldView.new()
		_hero_view.data = hero
		_hero_view.position = Vector2(0.0, HERO_SLOT_Y)
		add_child(_hero_view)


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


func is_over_hero_slot(world_pos: Vector2) -> bool:
	var slot_global := global_position + Vector2(0.0, HERO_SLOT_Y)
	var rect := Rect2(
		slot_global - Vector2(HeroFieldView.W, HeroFieldView.H) * 0.5,
		Vector2(HeroFieldView.W, HeroFieldView.H)
	)
	return rect.has_point(world_pos)


# Área "general" del battlefield. Drops fuera de esta área no son válidos —
# la carta vuelve sola al slot porque su _is_dragging quedó en false.
func is_over_battlefield(world_pos: Vector2) -> bool:
	var rect := Rect2(
		global_position - Vector2(DROP_AREA_MARGIN_X, DROP_AREA_MARGIN_TOP),
		Vector2(DROP_AREA_MARGIN_X * 2.0, DROP_AREA_MARGIN_TOP + DROP_AREA_MARGIN_BOTTOM)
	)
	return rect.has_point(world_pos)


func _relayout_enemies() -> void:
	var count := _enemies.size()
	for i in count:
		_enemy_views[i].position = Vector2(_enemy_x(i, count), ENEMY_SLOT_Y)


func _enemy_x(i: int, count: int) -> float:
	if count <= 1:
		return 0.0
	var t := remap(float(i), 0.0, float(count - 1), -1.0, 1.0)
	return t * ENEMY_SPACING * (count - 1) * 0.5
