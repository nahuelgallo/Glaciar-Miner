class_name DeckManagementMenu
extends Control

# Overlay para gestionar el mazo desde la exploración (§7.7).
# Muestra todas las cartas del deck:
#   - Sección "Héroes" arriba: clickeables para designar como signature.
#   - Sección "Otras cartas" abajo: read-only.
# El líder actual se marca con ★ y un borde dorado.
#
# Cierre: botón X, ESC, o click fuera del panel.

signal closed()

const PANEL_W: float = 1100.0
const PANEL_H: float = 600.0
const CARD_W: float = 110.0
const CARD_H: float = 160.0
const CARD_SPACING: float = 14.0


func _ready() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	position = Vector2.ZERO
	size = vp_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	_build()


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, size.x, size.y), Color(0.0, 0.0, 0.0, 0.72))


func _build() -> void:
	var deck := RunState.ensure_deck()
	var panel_pos := Vector2((size.x - PANEL_W) * 0.5, (size.y - PANEL_H) * 0.5)

	var panel := Panel.new()
	panel.position = panel_pos
	panel.size = Vector2(PANEL_W, PANEL_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.15, 0.18)
	sb.border_color = Color(0.85, 0.78, 0.55)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var title := _make_label(22, Color(0.95, 0.92, 0.78))
	title.position = panel_pos + Vector2(0.0, 18.0)
	title.size = Vector2(PANEL_W, 28.0)
	title.text = "MAZO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var sig_card := RunState.get_signature_card()
	var sig_text := "Sin líder designado — clic en un héroe para elegir uno"
	if sig_card != null:
		sig_text = "★ Líder actual: %s" % sig_card.card_name
	var sig_label := _make_label(13, Color(0.95, 0.92, 0.55))
	sig_label.position = panel_pos + Vector2(0.0, 50.0)
	sig_label.size = Vector2(PANEL_W, 18.0)
	sig_label.text = sig_text
	sig_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sig_label)

	# Sección héroes
	var heroes_title := _make_label(14, Color(0.85, 0.85, 0.88))
	heroes_title.position = panel_pos + Vector2(40.0, 88.0)
	heroes_title.size = Vector2(PANEL_W - 80.0, 20.0)
	heroes_title.text = "Héroes — clic para designar como líder"
	add_child(heroes_title)

	var heroes_row := HBoxContainer.new()
	heroes_row.position = panel_pos + Vector2(40.0, 116.0)
	heroes_row.add_theme_constant_override("separation", int(CARD_SPACING))
	add_child(heroes_row)

	var hero_count := 0
	for c in deck:
		if c.type == CardData.Type.HERO:
			heroes_row.add_child(_build_card_entry(c, true))
			hero_count += 1
	if hero_count == 0:
		var no_heroes := _make_label(12, Color(0.55, 0.58, 0.62))
		no_heroes.position = panel_pos + Vector2(40.0, 130.0)
		no_heroes.size = Vector2(PANEL_W - 80.0, 20.0)
		no_heroes.text = "(no hay héroes en el mazo)"
		add_child(no_heroes)

	# Sección "otras cartas"
	var others_title := _make_label(14, Color(0.85, 0.85, 0.88))
	others_title.position = panel_pos + Vector2(40.0, 320.0)
	others_title.size = Vector2(PANEL_W - 80.0, 20.0)
	others_title.text = "Otras cartas del mazo"
	add_child(others_title)

	var others_row := HBoxContainer.new()
	others_row.position = panel_pos + Vector2(40.0, 348.0)
	others_row.add_theme_constant_override("separation", int(CARD_SPACING))
	add_child(others_row)

	var others_count := 0
	for c in deck:
		if c.type != CardData.Type.HERO:
			others_row.add_child(_build_card_entry(c, false))
			others_count += 1

	# Counter total
	var counter := _make_label(11, Color(0.55, 0.58, 0.62))
	counter.position = panel_pos + Vector2(40.0, PANEL_H - 36.0)
	counter.size = Vector2(PANEL_W - 80.0, 16.0)
	counter.text = "Mazo: %d cartas (%d héroes)" % [deck.size(), hero_count]
	add_child(counter)

	# Botón cerrar
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.position = panel_pos + Vector2(PANEL_W - 38.0, 8.0)
	close_btn.size = Vector2(30.0, 30.0)
	close_btn.pressed.connect(close)
	add_child(close_btn)


func _build_card_entry(card: CardData, clickable: bool) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(CARD_W, CARD_H + 22.0)

	var visual := BigCardVisual.new()
	visual.card = card
	visual.w = CARD_W
	visual.h = CARD_H
	container.add_child(visual)

	# Marker dorado si es el signature actual
	if card.id == RunState.signature_card_id:
		var marker := _make_label(11, Color(0.95, 0.92, 0.55))
		marker.position = Vector2(0.0, CARD_H + 4.0)
		marker.size = Vector2(CARD_W, 16.0)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.text = "★ LÍDER"
		container.add_child(marker)
		# Borde dorado encima del visual
		var border := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		sb.border_color = Color(0.95, 0.92, 0.55)
		sb.set_border_width_all(3)
		border.add_theme_stylebox_override("panel", sb)
		border.position = Vector2(-3.0, -3.0)
		border.size = Vector2(CARD_W + 6.0, CARD_H + 6.0)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(border)

	if clickable:
		var btn := Button.new()
		btn.flat = true
		btn.size = Vector2(CARD_W, CARD_H)
		btn.tooltip_text = "Designar como líder"
		btn.pressed.connect(_on_hero_clicked.bind(card))
		container.add_child(btn)

	return container


func _on_hero_clicked(card: CardData) -> void:
	RunState.set_signature(card.id)
	# Rebuild para refrescar markers + texto del título
	_clear_children()
	_build()


func _clear_children() -> void:
	for child in get_children():
		child.queue_free()


func _make_label(font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func close() -> void:
	closed.emit()
	queue_free()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var rect := Rect2(
			Vector2((size.x - PANEL_W) * 0.5, (size.y - PANEL_H) * 0.5),
			Vector2(PANEL_W, PANEL_H)
		)
		if not rect.has_point(event.position):
			close()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
