class_name HandManager
extends Node2D

# Re-emitida cuando una carta arrastrada se suelta. El caller (main.gd)
# decide si el drop fue válido y llama a remove_view() si la carta debe
# salir de la mano.
signal card_dropped(card: CardData, drop_position: Vector2, view: CardView)

@export var hand_width: float = 720.0
@export var card_spacing: float = 110.0
@export var tooltip_offset: Vector2 = Vector2(0.0, 100.0)

var _slots: Array[Node2D] = []
var _views: Array[CardView] = []
var _data: Array[CardData] = []
var _tooltip: CardTooltip
var _hovered_view: CardView


func _ready() -> void:
	_tooltip = CardTooltip.new()
	add_child(_tooltip)


func add_card(card: CardData) -> void:
	_data.append(card)
	var slot := Node2D.new()
	slot.name = "Slot%d" % _slots.size()
	add_child(slot)
	_slots.append(slot)

	var view := CardView.new()
	view.data = card
	view.target_node = slot
	view.global_position = global_position
	view.hover_started.connect(_on_card_hover_started)
	view.hover_ended.connect(_on_card_hover_ended)
	view.dropped.connect(_on_card_view_dropped)
	add_child(view)
	_views.append(view)
	_relayout()


func remove_card(index: int) -> void:
	if index < 0 or index >= _data.size():
		return
	if _views[index] == _hovered_view:
		_hovered_view = null
		_tooltip.hide()
	_data.remove_at(index)
	_slots[index].queue_free()
	_slots.remove_at(index)
	_views[index].queue_free()
	_views.remove_at(index)
	_relayout()


func size() -> int:
	return _data.size()


func remove_view(view: CardView) -> void:
	var idx := _views.find(view)
	if idx >= 0:
		remove_card(idx)


func _on_card_view_dropped(view: CardView, drop_position: Vector2) -> void:
	var idx := _views.find(view)
	if idx == -1:
		return
	card_dropped.emit(_data[idx], drop_position, view)


func _relayout() -> void:
	var count := _slots.size()
	for i in count:
		_slots[i].transform = _card_pose(i, count)


# Layout recto: cartas en línea horizontal, sin rotación, con clamp por
# hand_width cuando hay muchas. Estilo Balatro.
func _card_pose(i: int, count: int) -> Transform2D:
	if count <= 1:
		return Transform2D(0.0, Vector2.ZERO)
	var t: float = remap(float(i), 0.0, float(count - 1), -1.0, 1.0)
	var ideal_span: float = card_spacing * float(count - 1)
	var span: float = minf(ideal_span, hand_width)
	var x: float = t * span * 0.5
	return Transform2D(0.0, Vector2(x, 0.0))


func _on_card_hover_started(view: CardView) -> void:
	var idx: int = _views.find(view)
	if idx == -1 or view.data == null:
		return
	_hovered_view = view
	_tooltip.show_for(view.data)
	# Tooltip se dibuja desde su top-left, así que centramos en x bajo la carta.
	var slot_pos: Vector2 = _slots[idx].global_position
	var top_left: Vector2 = slot_pos + tooltip_offset - Vector2(CardTooltip.PANEL_WIDTH * 0.5, 0.0)
	_tooltip.global_position = top_left


# Solo escondemos si la carta que sale del hover es la que estaba mostrando
# tooltip — protege contra el orden no garantizado de exit/enter al pasar
# rápido entre cartas adyacentes.
func _on_card_hover_ended(view: CardView) -> void:
	if view == _hovered_view:
		_hovered_view = null
		_tooltip.hide()
