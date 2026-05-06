class_name DragArrowOverlay
extends Node2D

# Flecha visual que aparece mientras arrastrás una carta. Va desde la mano
# hacia el target apuntado.
#
# Mecánica de targeting:
#   - Si NO hay candidate targets (ej. carta heal_player con drop libre),
#     la flecha apunta directamente al mouse.
#   - Si HAY candidates, la flecha apunta al "default" (el del medio).
#   - Cuando el mouse se acerca a un candidate específico (dentro de
#     SNAP_DISTANCE), la flecha se interpola hacia ese target. Más cerca
#     del mouse = más snap. Lejos = se mantiene en default.

const SNAP_DISTANCE: float = 110.0
const ARROW_HEAD_SIZE: float = 14.0
const ARROW_COLOR_DEFAULT := Color(0.95, 0.92, 0.55, 0.85)
const ARROW_COLOR_LOCKED := Color(0.55, 0.95, 0.65, 0.95)

var _enabled: bool = false
var _origin: Vector2
var _target: Vector2
var _is_locked: bool = false  # true si snappeó a un candidate específico


func _ready() -> void:
	z_index = 200  # encima de cualquier otra cosa


func _draw() -> void:
	if not _enabled:
		return
	var color := ARROW_COLOR_LOCKED if _is_locked else ARROW_COLOR_DEFAULT
	# Línea principal
	draw_line(_origin, _target, color, 3.0, true)
	# Cabeza de flecha
	var dir := (_target - _origin).normalized()
	if dir == Vector2.ZERO:
		return
	var perp := Vector2(-dir.y, dir.x)
	var p_a := _target - dir * ARROW_HEAD_SIZE + perp * ARROW_HEAD_SIZE * 0.5
	var p_b := _target - dir * ARROW_HEAD_SIZE - perp * ARROW_HEAD_SIZE * 0.5
	draw_polygon([_target, p_a, p_b], [color, color, color])


# `candidate_targets`: lista de positions globales de targets válidos (slots
# de héroe vacíos / enemigos vivos / etc.). Si está vacía, la flecha apunta
# directo al mouse.
func update_drag(origin_pos: Vector2, mouse_pos: Vector2, candidate_targets: Array[Vector2]) -> void:
	_enabled = true
	_origin = origin_pos
	if candidate_targets.is_empty():
		_target = mouse_pos
		_is_locked = false
		queue_redraw()
		return
	# Default: el del medio (en orden de la lista).
	var default_target: Vector2 = candidate_targets[candidate_targets.size() / 2]
	# Snap al más cercano si el mouse está dentro de SNAP_DISTANCE.
	var closest := default_target
	var closest_d := SNAP_DISTANCE
	for t in candidate_targets:
		var d := mouse_pos.distance_to(t)
		if d < closest_d:
			closest_d = d
			closest = t
	# Strength del snap: 1.0 cuando el mouse está exactamente sobre el target,
	# 0.0 cuando está a SNAP_DISTANCE o más. Lerp para transición suave.
	var snap_strength: float = 1.0 - clampf(closest_d / SNAP_DISTANCE, 0.0, 1.0)
	_target = default_target.lerp(closest, snap_strength)
	_is_locked = snap_strength > 0.6
	queue_redraw()


func clear() -> void:
	_enabled = false
	_is_locked = false
	queue_redraw()
