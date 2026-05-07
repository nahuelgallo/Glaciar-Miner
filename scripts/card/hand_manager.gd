class_name HandManager
extends Node2D

# Re-emitida cuando una carta arrastrada se suelta. El caller (main.gd)
# decide si el drop fue válido y llama a remove_view() si la carta debe
# salir de la mano.
signal card_dropped(card: CardData, drop_position: Vector2, view: CardView)

# Re-emitidas cuando el mouse entra/sale de una carta de la mano. El caller
# las usa para alimentar el preview (ver `CardPreviewView`). slot_global_pos
# es la posición del slot original (sin lift), útil para colocar el preview
# cerca de la carta hovered.
signal card_hover_started(card: CardData, slot_global_pos: Vector2)
signal card_hover_ended()
# Disparada al click derecho sobre una carta. El caller abre la modal.
signal card_inspect_requested(card: CardData)
# Re-emitidas cuando una carta inicia/termina el drag. main.gd las usa para
# encender/apagar el highlight de drop targets y la flecha apuntadora.
signal card_drag_started(card: CardData, view: CardView)
signal card_drag_ended()

@export var hand_width: float = 720.0
@export var card_spacing: float = 110.0

var _slots: Array[Node2D] = []
var _views: Array[CardView] = []
var _data: Array[CardData] = []
var _hovered_view: CardView


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
	view.inspect_requested.connect(_on_card_view_inspect_requested)
	view.drag_started.connect(_on_card_view_drag_started)
	add_child(view)
	_views.append(view)
	_relayout()


func remove_card(index: int) -> void:
	if index < 0 or index >= _data.size():
		return
	if _views[index] == _hovered_view:
		_hovered_view = null
		card_hover_ended.emit()
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
	if idx >= 0:
		card_dropped.emit(_data[idx], drop_position, view)
	# Siempre notificamos drag_ended para que el caller limpie highlight/arrow
	# aun si la view se removió mientras dragueaba (edge case).
	card_drag_ended.emit()


func _on_card_view_drag_started(view: CardView) -> void:
	var idx := _views.find(view)
	if idx == -1:
		return
	card_drag_started.emit(_data[idx], view)


func _on_card_view_inspect_requested(view: CardView) -> void:
	var idx := _views.find(view)
	if idx == -1:
		return
	card_inspect_requested.emit(_data[idx])


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
	card_hover_started.emit(view.data, _slots[idx].global_position)


# Solo escondemos si la carta que sale del hover es la que estaba mostrando
# preview — protege contra el orden no garantizado de exit/enter al pasar
# rápido entre cartas adyacentes.
func _on_card_hover_ended(view: CardView) -> void:
	if view == _hovered_view:
		_hovered_view = null
		card_hover_ended.emit()
