class_name PauseMenu
extends Control

# Overlay de pausa. Bloquea input al juego de abajo y ofrece:
#   - Continuar (cierra el menú)
#   - Reiniciar run (reset completo + vuelve a exploración)
#   - Volver a explorar (manual abort, sin reset)

signal restart_requested()
signal back_to_exploration_requested()

const PANEL_W: float = 380.0
const PANEL_H: float = 280.0


func _ready() -> void:
	# El parent es Node2D — anchors no funcionan, forzamos size manual.
	var vp_size: Vector2 = get_viewport_rect().size
	position = Vector2.ZERO
	size = vp_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	_build()


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, size.x, size.y), Color(0.0, 0.0, 0.0, 0.72))


func _build() -> void:
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

	var title := _make_label(20, Color(0.95, 0.92, 0.78))
	title.position = panel_pos + Vector2(0.0, 24.0)
	title.size = Vector2(PANEL_W, 28.0)
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var btn_continue := _make_button("Continuar")
	btn_continue.position = panel_pos + Vector2((PANEL_W - 240.0) * 0.5, 78.0)
	btn_continue.pressed.connect(close)
	add_child(btn_continue)

	var btn_back := _make_button("Volver a explorar")
	btn_back.position = panel_pos + Vector2((PANEL_W - 240.0) * 0.5, 132.0)
	btn_back.pressed.connect(_on_back_pressed)
	add_child(btn_back)

	var btn_restart := _make_button("Reiniciar run")
	btn_restart.position = panel_pos + Vector2((PANEL_W - 240.0) * 0.5, 186.0)
	btn_restart.pressed.connect(_on_restart_pressed)
	add_child(btn_restart)


func _make_label(font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size = Vector2(240.0, 44.0)
	return btn


func close() -> void:
	queue_free()


func _on_back_pressed() -> void:
	back_to_exploration_requested.emit()
	close()


func _on_restart_pressed() -> void:
	restart_requested.emit()
	close()


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
