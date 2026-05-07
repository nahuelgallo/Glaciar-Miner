class_name CardDetailModal
extends Control

# Ventana modal abierta al hacer click derecho sobre una carta. Muestra la
# carta agrandada con todos sus datos.
#
# Cierre: botón X (esquina superior derecha del panel), ESC, o click fuera
# del panel.

const MODAL_W: float = 720.0
const MODAL_H: float = 460.0
const CARD_W: float = 240.0
const CARD_H: float = 360.0

var card: CardData


func _ready() -> void:
	# El parent es Node2D, así que los anchors no resuelven el size automaticamente.
	# Forzamos size = viewport size para que el modal cubra toda la pantalla.
	var vp_size: Vector2 = get_viewport_rect().size
	position = Vector2.ZERO
	size = vp_size
	mouse_filter = Control.MOUSE_FILTER_STOP  # bloquea input al juego de abajo
	gui_input.connect(_on_gui_input)
	_build()


# Dim del background. El panel central lo dibujan los Controls hijos para
# que el modal siga el sizing semántico de Container/Panel.
func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, size.x, size.y), Color(0.0, 0.0, 0.0, 0.72))


func _build() -> void:
	if card == null:
		return
	var modal_pos := Vector2((size.x - MODAL_W) * 0.5, (size.y - MODAL_H) * 0.5)
	var panel := Panel.new()
	panel.position = modal_pos
	panel.size = Vector2(MODAL_W, MODAL_H)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP  # consume click adentro
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.15, 0.18)
	sb.border_color = Color(0.85, 0.78, 0.55)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	# Carta agrandada (left)
	var card_view := _build_card_view()
	card_view.position = Vector2(modal_pos.x + 30.0, modal_pos.y + 50.0)
	add_child(card_view)

	# Info detallada (right)
	_build_info_panel(modal_pos)

	# Botón X cerrar
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.position = modal_pos + Vector2(MODAL_W - 38.0, 8.0)
	close_btn.size = Vector2(30.0, 30.0)
	close_btn.pressed.connect(close)
	add_child(close_btn)


func _build_card_view() -> Node2D:
	var node := BigCardVisual.new()
	node.card = card
	node.w = CARD_W
	node.h = CARD_H
	return node


func _build_info_panel(modal_pos: Vector2) -> void:
	var info_x := modal_pos.x + 30.0 + CARD_W + 30.0
	var info_y := modal_pos.y + 50.0
	var info_w := MODAL_W - 30.0 - CARD_W - 30.0 - 30.0

	# Nombre grande
	var name_label := _make_label(22, Color(0.95, 0.92, 0.78))
	name_label.position = Vector2(info_x, info_y)
	name_label.size = Vector2(info_w, 32.0)
	name_label.text = card.card_name
	add_child(name_label)

	# Subtitle: tipo · facción · rareza
	var subtitle := _make_label(13, Color(0.75, 0.78, 0.85))
	subtitle.position = Vector2(info_x, info_y + 36.0)
	subtitle.size = Vector2(info_w, 18.0)
	subtitle.text = "%s · %s · %s" % [
		_type_text(card.type),
		_faction_text(card.faction),
		_rarity_text(card.rarity),
	]
	add_child(subtitle)

	# Stats (si HERO: HP/DEF; si action/effect: recycle)
	var stats_label := _make_label(15, Color(1.0, 0.85, 0.55))
	stats_label.position = Vector2(info_x, info_y + 64.0)
	stats_label.size = Vector2(info_w, 22.0)
	stats_label.text = _stats_text()
	add_child(stats_label)

	# Tags (si tiene)
	if not card.tags.is_empty():
		var tags_label := _make_label(12, Color(0.85, 0.95, 0.55))
		tags_label.position = Vector2(info_x, info_y + 90.0)
		tags_label.size = Vector2(info_w, 18.0)
		var parts: Array[String] = []
		for t in card.tags:
			parts.append("[" + String(t) + "]")
		tags_label.text = "Tags: " + " ".join(parts)
		add_child(tags_label)

	# Descripción (autowrap, mucho espacio)
	var desc_label := _make_label(13, Color(0.92, 0.92, 0.95))
	desc_label.position = Vector2(info_x, info_y + 120.0)
	desc_label.size = Vector2(info_w, 180.0)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc_label.text = card.description
	add_child(desc_label)

	# Effect raw (debug-ish)
	if not card.effect.is_empty():
		var effect_label := _make_label(11, Color(0.55, 0.78, 0.95))
		effect_label.position = Vector2(info_x, info_y + 320.0)
		effect_label.size = Vector2(info_w, 36.0)
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var effect_str := "Efecto: " + str(card.effect)
		effect_label.text = effect_str
		add_child(effect_label)


func _stats_text() -> String:
	if card.type == CardData.Type.HERO:
		return "HP %d   ·   DEF %d" % [card.hp, card.defense]
	return "Reciclaje: %d minerales" % card.recycle_value


func _make_label(font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func close() -> void:
	queue_free()


func _on_gui_input(event: InputEvent) -> void:
	# Click fuera del panel = cierre
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var modal_rect := Rect2(
			Vector2((size.x - MODAL_W) * 0.5, (size.y - MODAL_H) * 0.5),
			Vector2(MODAL_W, MODAL_H)
		)
		if not modal_rect.has_point(event.position):
			close()


func _unhandled_key_input(event: InputEvent) -> void:
	# ESC también cierra
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _type_text(t: CardData.Type) -> String:
	match t:
		CardData.Type.HERO:   return "Héroe"
		CardData.Type.ACTION: return "Acción"
		CardData.Type.EFFECT: return "Efecto"
	return ""


func _faction_text(f: CardData.Faction) -> String:
	match f:
		CardData.Faction.PERONIST:    return "Peronistas"
		CardData.Faction.LIBERTARIAN: return "LLA"
		CardData.Faction.MACRIST:     return "PRO"
		CardData.Faction.LEFTIST:     return "FIT"
		CardData.Faction.APOLITICAL:  return "Apolítico"
		CardData.Faction.OUTSIDER:    return "Outsider"
	return "Neutral"


func _rarity_text(r: CardData.Rarity) -> String:
	match r:
		CardData.Rarity.COMMON:    return "Común"
		CardData.Rarity.RARE:      return "Rara"
		CardData.Rarity.EPIC:      return "Épica"
		CardData.Rarity.LEGENDARY: return "Legendaria"
	return ""
