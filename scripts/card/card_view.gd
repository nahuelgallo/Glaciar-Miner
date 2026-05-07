class_name CardView
extends Node2D

signal hover_started(view: CardView)
signal hover_ended(view: CardView)
# Disparada cuando empieza el drag (left-click + start drag).
signal drag_started(view: CardView)
# Disparada al soltar el botón izquierdo después de un drag — incluso si el
# release ocurre fuera del Area2D. drop_position es la posición global del
# mouse en ese instante.
signal dropped(view: CardView, drop_position: Vector2)
# Disparada al click derecho. El caller abre la ventana modal de detalle.
signal inspect_requested(view: CardView)

const CARD_WIDTH: float = 110.0
const CARD_HEIGHT: float = 154.0
# Extra height en el Area2D de hover. Cuando la carta se eleva (hover_lift),
# el Area2D se va con ella y el mouse queda en "tierra de nadie" entre la
# zona elevada y la posición original — eso provoca toggle infinito de
# enter/exit. Extender el área hacia abajo cubre la posición original aun
# con la carta levantada.
const HOVER_AREA_EXTRA: float = 90.0

@export var follow_speed: float = 18.0
@export var hover_scale: float = 1.20
@export var hover_lift: float = -85.0
@export var drag_follow_speed: float = 26.0
@export var tilt_strength: float = 0.0009
@export var max_drag_tilt: float = 0.55
@export var tilt_smoothing: float = 22.0

# Solo una carta puede estar en drag a la vez. Sin esto, cuando dos cartas
# solapadas reciben el mismo press event, ambas entran en drag y al soltar
# ambas emiten `dropped`, jugando dos cartas con un solo click.
static var _global_drag_owner: CardView = null

var data: CardData
var target_node: Node2D

var _is_hovered: bool = false
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _prev_pos: Vector2
var _drag_tilt: float = 0.0
var _name_label: Label
var _stats_label: Label


func _ready() -> void:
	_build_input_area()
	_build_labels()
	_prev_pos = global_position


func _draw() -> void:
	var rect := Rect2(-CARD_WIDTH * 0.5, -CARD_HEIGHT * 0.5, CARD_WIDTH, CARD_HEIGHT)
	# Fondo = facción (§8.2). Borde = tipo de carta.
	draw_rect(rect, _faction_color())
	draw_rect(rect, _type_outline_color(), false, 4.0)
	# Banda inferior para stats
	var band := Rect2(rect.position.x, rect.position.y + CARD_HEIGHT - 28.0, CARD_WIDTH, 28.0)
	draw_rect(band, Color(0.08, 0.06, 0.05, 0.85))


func _process(delta: float) -> void:
	if _is_dragging:
		_process_drag(delta)
	elif target_node and is_instance_valid(target_node):
		_process_follow(delta)
	z_index = 2 if _is_dragging else (1 if _is_hovered else 0)


func _process_follow(delta: float) -> void:
	var target_pos: Vector2 = target_node.global_position
	if _is_hovered:
		target_pos.y += hover_lift
	var target_rot: float = target_node.global_rotation
	var t: float = 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(target_pos, t)
	rotation = lerp_angle(rotation, target_rot, t)
	var hover_factor: float = hover_scale if _is_hovered else 1.0
	var target_scale: Vector2 = Vector2.ONE * hover_factor
	scale = scale.lerp(target_scale, t)
	_drag_tilt = lerpf(_drag_tilt, 0.0, t)
	_prev_pos = global_position


func _process_drag(delta: float) -> void:
	var target_pos: Vector2 = get_global_mouse_position() + _drag_offset
	var t: float = 1.0 - exp(-drag_follow_speed * delta)
	var new_pos: Vector2 = global_position.lerp(target_pos, t)
	var dx: float = new_pos.x - _prev_pos.x
	var safe_delta: float = maxf(delta, 0.0001)
	var velocity_x: float = dx / safe_delta
	global_position = new_pos
	_prev_pos = new_pos
	var raw_tilt: float = velocity_x * tilt_strength
	var target_tilt: float = clampf(raw_tilt, -max_drag_tilt, max_drag_tilt)
	var ts: float = 1.0 - exp(-tilt_smoothing * delta)
	_drag_tilt = lerpf(_drag_tilt, target_tilt, ts)
	rotation = _drag_tilt
	scale = scale.lerp(Vector2.ONE * hover_scale, t)


func _build_input_area() -> void:
	var area := Area2D.new()
	area.name = "InputArea"
	area.input_pickable = true
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)
	area.input_event.connect(_on_input_event)
	add_child(area)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# Extendido hacia abajo para que la posición original siga siendo zona
	# de hover cuando la carta está elevada (ver HOVER_AREA_EXTRA).
	rect.size = Vector2(CARD_WIDTH, CARD_HEIGHT + HOVER_AREA_EXTRA)
	shape.shape = rect
	shape.position = Vector2(0.0, HOVER_AREA_EXTRA * 0.5)
	area.add_child(shape)


func _build_labels() -> void:
	_name_label = Label.new()
	_name_label.text = data.card_name if data else "?"
	_name_label.position = Vector2(-CARD_WIDTH * 0.5 + 8.0, -CARD_HEIGHT * 0.5 + 6.0)
	_name_label.size = Vector2(CARD_WIDTH - 16.0, 24.0)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.add_theme_color_override("font_color", Color(0.08, 0.06, 0.03))
	_name_label.add_theme_font_size_override("font_size", 14)
	add_child(_name_label)

	_stats_label = Label.new()
	_stats_label.text = _stats_text()
	_stats_label.position = Vector2(-CARD_WIDTH * 0.5 + 8.0, CARD_HEIGHT * 0.5 - 24.0)
	_stats_label.size = Vector2(CARD_WIDTH - 16.0, 20.0)
	_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_label.add_theme_color_override("font_color", Color.WHITE)
	_stats_label.add_theme_font_size_override("font_size", 12)
	add_child(_stats_label)


func _stats_text() -> String:
	if data == null:
		return ""
	if data.type == CardData.Type.HERO:
		var s := "HP %d  DEF %d" % [data.hp, data.defense]
		if data.has_tag(CardData.TAG_LEADER):
			s += "  [LEADER]"
		return s
	return _type_short()


# Paleta del GDD §8.2.
func _faction_color() -> Color:
	if data == null:
		return Color(0.7, 0.68, 0.62)
	match data.faction:
		CardData.Faction.PERONIST:    return Color(0.55, 0.78, 0.95)  # celeste
		CardData.Faction.LIBERTARIAN: return Color(0.62, 0.42, 0.85)  # violeta
		CardData.Faction.MACRIST:     return Color(0.95, 0.85, 0.35)  # amarillo
		CardData.Faction.LEFTIST:     return Color(0.85, 0.30, 0.30)  # rojo
		CardData.Faction.APOLITICAL:  return Color(0.78, 0.80, 0.82)  # gris claro metálico
		CardData.Faction.OUTSIDER:    return Color(0.28, 0.26, 0.24)  # gris carbón
		_:                            return Color(0.85, 0.83, 0.78)  # neutral (efectos sin facción)


# Borde por tipo de carta para que Hero/Action/Effect siga siendo distinguible
# de un vistazo además del color de facción.
func _type_outline_color() -> Color:
	if data == null:
		return Color(0.12, 0.09, 0.05)
	match data.type:
		CardData.Type.HERO:    return Color(0.15, 0.10, 0.05)  # marrón oscuro
		CardData.Type.ACTION:  return Color(0.95, 0.85, 0.35)  # dorado
		CardData.Type.EFFECT:  return Color(0.55, 0.85, 0.65)  # verde menta
	return Color(0.12, 0.09, 0.05)


func _type_short() -> String:
	if data == null:
		return ""
	match data.type:
		CardData.Type.ACTION: return "ACCIÓN"
		CardData.Type.EFFECT: return "EFECTO"
		CardData.Type.HERO:   return "HÉROE"
	return ""


func _on_mouse_entered() -> void:
	_is_hovered = true
	hover_started.emit(self)


func _on_mouse_exited() -> void:
	_is_hovered = false
	hover_ended.emit(self)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	# Right click → ventana modal de detalle.
	if event.button_index == MOUSE_BUTTON_RIGHT:
		inspect_requested.emit(self)
		return
	# Left click → inicia drag. El release se escucha globalmente en
	# _unhandled_input para no perderlo si el mouse salió del Area2D.
	if event.button_index == MOUSE_BUTTON_LEFT:
		# Si ya hay otra carta draggeándose, ignoramos. Combinado con
		# Viewport.physics_object_picking_first_only, esto garantiza que un
		# click sobre cartas solapadas solo agarra la de arriba.
		if _global_drag_owner != null:
			return
		_global_drag_owner = self
		_is_dragging = true
		_drag_offset = global_position - get_global_mouse_position()
		drag_started.emit(self)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_is_dragging = false
		if _global_drag_owner == self:
			_global_drag_owner = null
		dropped.emit(self, get_global_mouse_position())
		get_viewport().set_input_as_handled()


# Cleanup defensivo: si la carta se queue_free'a en medio de un drag (por
# ejemplo al jugarse), liberar el lock global.
func _exit_tree() -> void:
	if _global_drag_owner == self:
		_global_drag_owner = null


# Animación de "carta jugada": detiene el follow al slot y mueve la carta
# hacia un destino con tween + scale down + rotación leve. Llama on_done al
# terminar para que el caller la remueva de la mano y la sume al descarte.
func play_to(target_global: Vector2, on_done: Callable = Callable()) -> void:
	target_node = null
	_is_dragging = false
	if _global_drag_owner == self:
		_global_drag_owner = null
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", target_global, 0.32) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.55, 0.55), 0.32) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "rotation", randf_range(-0.6, 0.6), 0.32) \
		.set_trans(Tween.TRANS_SINE)
	if on_done.is_valid():
		tween.chain().tween_callback(on_done)
