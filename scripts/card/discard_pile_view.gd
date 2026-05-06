class_name DiscardPileView
extends Node2D

# Pila visual del descarte. Cada carta jugada (action/effect "goes to discard"
# §7.1; las HERO no van al descarte normalmente pero por ahora también caen
# acá hasta que exista la mecánica completa de "carta en juego" §7.7).
#
# Visual: stack de rectángulos para sugerir profundidad, la carta superior
# muestra nombre y color de facción. Click derecho abre la modal de detalle
# con la última carta del descarte.

signal inspect_requested(card: CardData)

const W: float = 100.0
const H: float = 140.0
const STACK_OFFSET: Vector2 = Vector2(1.5, -2.0)
const MAX_VISIBLE_LAYERS: int = 5

var _last_card: CardData
var _count: int = 0

var _name_label: Label
var _count_label: Label


func _ready() -> void:
	_build()
	_build_input_area()
	_refresh()


func _build_input_area() -> void:
	var area := Area2D.new()
	area.name = "InputArea"
	area.input_pickable = true
	area.input_event.connect(_on_input_event)
	add_child(area)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(W, H)
	shape.shape = rect
	area.add_child(shape)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and _last_card != null:
		inspect_requested.emit(_last_card)


func _draw() -> void:
	var layers := mini(_count, MAX_VISIBLE_LAYERS)
	if layers == 0:
		# Slot vacío
		var empty_rect := Rect2(-W * 0.5, -H * 0.5, W, H)
		draw_rect(empty_rect, Color(0.12, 0.10, 0.08, 0.6))
		draw_rect(empty_rect, Color(0.45, 0.40, 0.35), false, 2.0)
		return
	# Capas de fondo (sombras del pile) + capa superior (carta visible)
	for i in range(layers - 1, -1, -1):
		var offset := STACK_OFFSET * float(i)
		var rect := Rect2(-W * 0.5 + offset.x, -H * 0.5 + offset.y, W, H)
		var color := _faction_color()
		if i > 0:
			color = color.darkened(0.25 + 0.05 * float(i))
		draw_rect(rect, color)
		draw_rect(rect, Color(0.12, 0.09, 0.05), false, 2.0)


func add_card(card: CardData) -> void:
	_last_card = card
	_count += 1
	_refresh()


func clear_pile() -> void:
	_last_card = null
	_count = 0
	_refresh()


func count() -> int:
	return _count


func _faction_color() -> Color:
	if _last_card == null:
		return Color(0.6, 0.6, 0.6)
	match _last_card.faction:
		CardData.Faction.PERONIST:    return Color(0.55, 0.78, 0.95)
		CardData.Faction.LIBERTARIAN: return Color(0.62, 0.42, 0.85)
		CardData.Faction.MACRIST:     return Color(0.95, 0.85, 0.35)
		CardData.Faction.LEFTIST:     return Color(0.85, 0.30, 0.30)
		CardData.Faction.APOLITICAL:  return Color(0.78, 0.80, 0.82)
		CardData.Faction.OUTSIDER:    return Color(0.28, 0.26, 0.24)
		_:                            return Color(0.85, 0.83, 0.78)


func _build() -> void:
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 11)
	_name_label.add_theme_color_override("font_color", Color(0.08, 0.06, 0.03))
	_name_label.position = Vector2(-W * 0.5 + 6.0, -H * 0.5 + 4.0)
	_name_label.size = Vector2(W - 12.0, 36.0)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_name_label)

	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", 13)
	_count_label.add_theme_color_override("font_color", Color.WHITE)
	_count_label.position = Vector2(-W * 0.5, H * 0.5 + 6.0)
	_count_label.size = Vector2(W, 18.0)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count_label)


func _refresh() -> void:
	if _last_card == null:
		_name_label.text = "(descarte)"
		_name_label.add_theme_color_override("font_color", Color(0.55, 0.50, 0.45))
	else:
		_name_label.text = _last_card.card_name
		_name_label.add_theme_color_override("font_color", Color(0.08, 0.06, 0.03))
	_count_label.text = "%d en pila" % _count
	queue_redraw()
