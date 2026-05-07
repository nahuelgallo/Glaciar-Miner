class_name DragArrowOverlay
extends Node2D

# Flecha visual mientras se arrastra una carta. Características:
#   - Curva Bezier cuadrática origen → mid (alto) → target, dibujada como
#     N segmentos cortos con grosor creciente hacia la cabeza
#   - Cabeza de flecha en el destino
#   - Breathing animado: alpha pulsa entre 50% y 100%
#   - Origen viene del caller cada frame: la flecha sigue a la carta
#     arrastrada (no queda anclada al fondo de la pantalla)
#   - Targeting: si NO hay candidates, apunta al mouse. Si HAY, default
#     al del medio; snappea al closer cuando el mouse se acerca

const SNAP_DISTANCE: float = 110.0
const ARROW_HEAD_SIZE: float = 18.0
const SEGMENT_COUNT: int = 14
const ARROW_COLOR_DEFAULT := Color(0.95, 0.92, 0.55)
const ARROW_COLOR_LOCKED := Color(0.55, 0.95, 0.65)
const BREATH_SPEED: float = 4.5  # rad/s del pulse

var _enabled: bool = false
var _origin: Vector2
var _target: Vector2
var _is_locked: bool = false
var _breath_time: float = 0.0


func _ready() -> void:
	z_index = 200
	set_process(false)


func _process(delta: float) -> void:
	if not _enabled:
		return
	_breath_time += delta
	queue_redraw()


func _draw() -> void:
	if not _enabled:
		return
	var color: Color = ARROW_COLOR_LOCKED if _is_locked else ARROW_COLOR_DEFAULT
	# Breathing alpha: 0..1 sin, mapped a 0.5..1.0
	var pulse: float = (sin(_breath_time * BREATH_SPEED) + 1.0) * 0.5
	color.a = lerpf(0.5, 1.0, pulse)

	# Bezier cuadrático: punto medio elevado para arc
	var dx: float = absf(_target.x - _origin.x)
	var lift: float = clampf(120.0 + dx * 0.15, 80.0, 220.0)
	var mid: Vector2 = (_origin + _target) * 0.5 + Vector2(0.0, -lift)

	# Sample puntos a lo largo del Bezier
	var points: Array[Vector2] = []
	for i in SEGMENT_COUNT + 1:
		var t: float = float(i) / float(SEGMENT_COUNT)
		points.append(_bezier(t, _origin, mid, _target))

	# Dibujar segmentos cortos con grosor creciente hacia la cabeza
	for i in SEGMENT_COUNT:
		var t: float = float(i) / float(SEGMENT_COUNT)
		var width: float = lerpf(2.0, 6.5, t)
		# Alpha también crece hacia la cabeza para resaltar el target
		var seg_color := color
		seg_color.a = color.a * lerpf(0.45, 1.0, t)
		draw_line(points[i], points[i + 1], seg_color, width)

	# Cabeza de flecha en el target
	var dir: Vector2 = (points[SEGMENT_COUNT] - points[SEGMENT_COUNT - 1]).normalized()
	if dir == Vector2.ZERO:
		return
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var p_a: Vector2 = _target - dir * ARROW_HEAD_SIZE + perp * ARROW_HEAD_SIZE * 0.7
	var p_b: Vector2 = _target - dir * ARROW_HEAD_SIZE - perp * ARROW_HEAD_SIZE * 0.7
	draw_polygon([_target, p_a, p_b], [color, color, color])


static func _bezier(t: float, p0: Vector2, p1: Vector2, p2: Vector2) -> Vector2:
	var u: float = 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2


# `origin_pos`: posición global de DONDE sale la flecha (típicamente la
#   carta arrastrada).
# `mouse_pos`: posición global del mouse (para snap a candidate).
# `candidate_targets`: positions globales de targets válidos. Vacío =
#   apuntar al mouse.
func update_drag(origin_pos: Vector2, mouse_pos: Vector2, candidate_targets: Array[Vector2]) -> void:
	_enabled = true
	set_process(true)
	_origin = origin_pos
	if candidate_targets.is_empty():
		_target = mouse_pos
		_is_locked = false
		queue_redraw()
		return
	var default_target: Vector2 = candidate_targets[candidate_targets.size() / 2]
	var closest: Vector2 = default_target
	var closest_d: float = SNAP_DISTANCE
	for t in candidate_targets:
		var d: float = mouse_pos.distance_to(t)
		if d < closest_d:
			closest_d = d
			closest = t
	var snap_strength: float = 1.0 - clampf(closest_d / SNAP_DISTANCE, 0.0, 1.0)
	_target = default_target.lerp(closest, snap_strength)
	_is_locked = snap_strength > 0.6
	queue_redraw()


func clear() -> void:
	_enabled = false
	_is_locked = false
	set_process(false)
	queue_redraw()
