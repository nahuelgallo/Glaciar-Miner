class_name ShrineMenu
extends Control

# Overlay que aparece al bumpear un shrine en exploración (§7.5).
# Opciones: curar HP, comprar booster pack básico, comprar pack avanzado.
# Costos en Argentite (mineral apolítico) por simplicidad. Cuando entren
# packs faction-typed reales, esto se generaliza.

signal closed()
signal recycle_requested()

const PANEL_W: float = 480.0
const PANEL_H: float = 540.0

const HEAL_COST: int = 3
const HEAL_AMOUNT: int = 5

const PACK_BASIC_COST: int = 5
const PACK_BASIC_CARDS: int = 2

const PACK_RARE_COST: int = 12
const PACK_RARE_CARDS: int = 3

var _last_purchase_label: Label
var _argentite_label: Label


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
	var panel_pos := Vector2((size.x - PANEL_W) * 0.5, (size.y - PANEL_H) * 0.5)
	var panel := Panel.new()
	panel.position = panel_pos
	panel.size = Vector2(PANEL_W, PANEL_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.18, 0.16)
	sb.border_color = Color(0.55, 0.95, 0.78)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var title := _make_label(22, Color(0.78, 0.95, 0.85))
	title.position = panel_pos + Vector2(0.0, 18.0)
	title.size = Vector2(PANEL_W, 28.0)
	title.text = "SHRINE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	_argentite_label = _make_label(13, Color(0.85, 0.85, 0.88))
	_argentite_label.position = panel_pos + Vector2(0.0, 50.0)
	_argentite_label.size = Vector2(PANEL_W, 18.0)
	_argentite_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_argentite_label)

	var btn_w := 360.0
	var btn_h := 64.0
	var btns_x := panel_pos.x + (PANEL_W - btn_w) * 0.5
	var y := panel_pos.y + 90.0

	# Heal
	_add_option(
		btns_x, y, btn_w, btn_h,
		"Curar (+%d HP)" % HEAL_AMOUNT,
		"Costo: %d Argentite" % HEAL_COST,
		_can_heal(),
		_on_heal_pressed
	)
	y += btn_h + 14.0

	# Pack básico
	_add_option(
		btns_x, y, btn_w, btn_h,
		"Pack básico — %d cartas" % PACK_BASIC_CARDS,
		"Costo: %d Argentite" % PACK_BASIC_COST,
		_can_afford(PACK_BASIC_COST),
		_on_pack_basic_pressed
	)
	y += btn_h + 14.0

	# Pack avanzado
	_add_option(
		btns_x, y, btn_w, btn_h,
		"Pack avanzado — %d cartas (más raras)" % PACK_RARE_CARDS,
		"Costo: %d Argentite" % PACK_RARE_COST,
		_can_afford(PACK_RARE_COST),
		_on_pack_rare_pressed
	)
	y += btn_h + 14.0

	# Reciclar carta — abre el deck menu en modo reciclar
	_add_option(
		btns_x, y, btn_w, btn_h,
		"Reciclar carta",
		"Abre el mazo · click destruye la carta y te devuelve minerales",
		not RunState.ensure_deck().is_empty(),
		_on_recycle_pressed
	)
	y += btn_h + 24.0

	# Last purchase log
	_last_purchase_label = _make_label(12, Color(0.85, 0.95, 0.55))
	_last_purchase_label.position = Vector2(panel_pos.x + 24.0, y)
	_last_purchase_label.size = Vector2(PANEL_W - 48.0, 110.0)
	_last_purchase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_last_purchase_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(_last_purchase_label)

	# Botón cerrar
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.position = panel_pos + Vector2(PANEL_W - 38.0, 8.0)
	close_btn.size = Vector2(30.0, 30.0)
	close_btn.pressed.connect(close)
	add_child(close_btn)

	_refresh_argentite_label()


func _add_option(x: float, y: float, w: float, h: float, title_text: String, sub_text: String, enabled: bool, on_pressed: Callable) -> void:
	var btn := Button.new()
	btn.position = Vector2(x, y)
	btn.size = Vector2(w, h)
	btn.disabled = not enabled
	btn.pressed.connect(on_pressed)
	add_child(btn)
	# Título arriba
	var t := _make_label(14, Color(0.95, 0.95, 0.85) if enabled else Color(0.55, 0.55, 0.55))
	t.position = Vector2(x + 14.0, y + 8.0)
	t.size = Vector2(w - 28.0, 22.0)
	t.text = title_text
	add_child(t)
	# Sub abajo
	var s := _make_label(11, Color(0.78, 0.85, 0.78) if enabled else Color(0.45, 0.45, 0.45))
	s.position = Vector2(x + 14.0, y + 32.0)
	s.size = Vector2(w - 28.0, 18.0)
	s.text = sub_text
	add_child(s)


func _can_heal() -> bool:
	if RunState.player_hp >= RunState.player_max_hp:
		return false
	return _can_afford(HEAL_COST)


func _can_afford(cost: int) -> bool:
	return RunState.minerals.get_amount(CardData.Faction.APOLITICAL) >= cost


func _refresh_argentite_label() -> void:
	if _argentite_label == null:
		return
	_argentite_label.text = "Tenés %d Argentite · HP %d/%d" % [
		RunState.minerals.get_amount(CardData.Faction.APOLITICAL),
		RunState.player_hp, RunState.player_max_hp
	]


func _on_heal_pressed() -> void:
	if not _can_heal():
		return
	if RunState.try_spend_minerals(CardData.Faction.APOLITICAL, HEAL_COST):
		RunState.heal_player(HEAL_AMOUNT)
		_log_purchase("+%d HP" % HEAL_AMOUNT)
	_rebuild()


func _on_pack_basic_pressed() -> void:
	if not _can_afford(PACK_BASIC_COST):
		return
	if RunState.try_spend_minerals(CardData.Faction.APOLITICAL, PACK_BASIC_COST):
		var added := RunState.add_random_cards_to_deck(PACK_BASIC_CARDS, 0.20)
		_log_purchase("Pack básico: %s" % _join_card_names(added))
	_rebuild()


func _on_pack_rare_pressed() -> void:
	if not _can_afford(PACK_RARE_COST):
		return
	if RunState.try_spend_minerals(CardData.Faction.APOLITICAL, PACK_RARE_COST):
		var added := RunState.add_random_cards_to_deck(PACK_RARE_CARDS, 0.40)
		_log_purchase("Pack avanzado: %s" % _join_card_names(added))
	_rebuild()


func _on_recycle_pressed() -> void:
	recycle_requested.emit()
	queue_free()


func _join_card_names(cards: Array[CardData]) -> String:
	var names: Array[String] = []
	for c in cards:
		names.append(c.card_name)
	return ", ".join(names)


func _log_purchase(msg: String) -> void:
	# Lo guardamos para que sobreviva al rebuild.
	set_meta("last_purchase", msg)


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_build()
	if has_meta("last_purchase"):
		_last_purchase_label.text = String(get_meta("last_purchase"))


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
