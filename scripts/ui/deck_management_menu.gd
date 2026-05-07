class_name DeckManagementMenu
extends Control

# Overlay para gestionar el mazo desde la exploración (§7.7).
#
# Layout:
#   - Header: título + estado del líder
#   - Toolbar de filtros por facción (Todas / Peronistas / LLA / PRO / FIT /
#     Apolíticos / Outsiders / Neutrales)
#   - Grid de héroes (clic = designar líder)
#   - Grid de otras cartas (read-only)
#   - Panel de detalle a la derecha (se llena al hacer hover sobre cualquier carta)
#   - Click derecho sobre cualquier carta = abre CardDetailModal con info completa
#
# Cierre: botón X, ESC, o click fuera del panel.

signal closed()

const PANEL_W: float = 1180.0
const PANEL_H: float = 620.0
const CARD_W: float = 110.0
const CARD_H: float = 160.0
const CARD_SPACING: float = 12.0

const FILTER_ALL: int = -1

var _active_filter: int = FILTER_ALL
var _hovered_card: CardData

var _grid_container: Control
var _detail_panel: Control
var _signature_label: Label


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
	panel.name = "MainPanel"
	panel.position = panel_pos
	panel.size = Vector2(PANEL_W, PANEL_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.15, 0.18)
	sb.border_color = Color(0.85, 0.78, 0.55)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	# Título
	var title := _make_label(22, Color(0.95, 0.92, 0.78))
	title.position = panel_pos + Vector2(0.0, 18.0)
	title.size = Vector2(PANEL_W, 28.0)
	title.text = "MAZO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# Estado del líder
	_signature_label = _make_label(13, Color(0.95, 0.92, 0.55))
	_signature_label.position = panel_pos + Vector2(0.0, 50.0)
	_signature_label.size = Vector2(PANEL_W, 18.0)
	_signature_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_refresh_signature_label()
	add_child(_signature_label)

	# Toolbar de filtros
	_build_filter_bar(panel_pos)

	# Detail panel a la derecha (siempre visible, se llena al hover)
	_build_detail_panel(panel_pos)

	# Grid container (heroes + others) — se rebuilda al cambiar filter
	_grid_container = Control.new()
	_grid_container.name = "GridArea"
	_grid_container.position = panel_pos + Vector2(30.0, 116.0)
	_grid_container.size = Vector2(820.0, PANEL_H - 150.0)
	_grid_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid_container)
	_rebuild_grid()

	# Counter total (abajo)
	var deck := RunState.ensure_deck()
	var hero_count := 0
	for c in deck:
		if c.type == CardData.Type.HERO:
			hero_count += 1
	var counter := _make_label(11, Color(0.55, 0.58, 0.62))
	counter.position = panel_pos + Vector2(30.0, PANEL_H - 28.0)
	counter.size = Vector2(PANEL_W - 60.0, 16.0)
	counter.text = "Mazo total: %d cartas (%d héroes) · click derecho sobre una carta para ver detalle completo" % [
		deck.size(), hero_count
	]
	add_child(counter)

	# Botón cerrar
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.position = panel_pos + Vector2(PANEL_W - 38.0, 8.0)
	close_btn.size = Vector2(30.0, 30.0)
	close_btn.pressed.connect(close)
	add_child(close_btn)


func _build_filter_bar(panel_pos: Vector2) -> void:
	var deck := RunState.ensure_deck()
	# (filter_id, label)
	var filters: Array = [
		[FILTER_ALL, "Todas"],
		[CardData.Faction.PERONIST, "PJ"],
		[CardData.Faction.LIBERTARIAN, "LLA"],
		[CardData.Faction.MACRIST, "PRO"],
		[CardData.Faction.LEFTIST, "FIT"],
		[CardData.Faction.APOLITICAL, "Apolíticos"],
		[CardData.Faction.OUTSIDER, "Outsiders"],
		[CardData.Faction.NONE, "Neutrales"],
	]
	var hbox := HBoxContainer.new()
	hbox.position = panel_pos + Vector2(30.0, 80.0)
	hbox.add_theme_constant_override("separation", 6)
	add_child(hbox)
	for entry in filters:
		var fid: int = entry[0]
		var label: String = entry[1]
		var count := _count_in_filter(deck, fid)
		var btn := Button.new()
		btn.text = "%s (%d)" % [label, count]
		btn.add_theme_font_size_override("font_size", 11)
		btn.custom_minimum_size = Vector2(0.0, 30.0)
		btn.toggle_mode = true
		btn.button_pressed = (fid == _active_filter)
		btn.pressed.connect(_on_filter_pressed.bind(fid))
		hbox.add_child(btn)


func _count_in_filter(deck: Array[CardData], filter_id: int) -> int:
	if filter_id == FILTER_ALL:
		return deck.size()
	var n := 0
	for c in deck:
		if int(c.faction) == filter_id:
			n += 1
	return n


func _on_filter_pressed(filter_id: int) -> void:
	_active_filter = filter_id
	# Rebuild solo los botones del filter bar (para refrescar pressed state)
	# y el grid. El detail panel y el header quedan.
	_clear_children()
	_build()


func _build_detail_panel(panel_pos: Vector2) -> void:
	_detail_panel = Control.new()
	_detail_panel.name = "DetailPanel"
	_detail_panel.position = panel_pos + Vector2(880.0, 116.0)
	_detail_panel.size = Vector2(270.0, PANEL_H - 150.0)
	_detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_detail_panel)
	_refresh_detail_panel()


func _refresh_detail_panel() -> void:
	for child in _detail_panel.get_children():
		child.queue_free()
	# Background panel
	var bg := Panel.new()
	bg.size = _detail_panel.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.15)
	sb.border_color = Color(0.30, 0.32, 0.36)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	bg.add_theme_stylebox_override("panel", sb)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_panel.add_child(bg)

	if _hovered_card == null:
		var msg := _make_label(12, Color(0.55, 0.58, 0.62))
		msg.position = Vector2(12.0, 12.0)
		msg.size = _detail_panel.size - Vector2(24.0, 24.0)
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		msg.text = "Pasá el mouse por una carta para ver detalle"
		_detail_panel.add_child(msg)
		return
	# Carta visual chica arriba
	var visual := BigCardVisual.new()
	visual.card = _hovered_card
	visual.w = 150.0
	visual.h = 210.0
	visual.position = Vector2((_detail_panel.size.x - 150.0) * 0.5, 14.0)
	_detail_panel.add_child(visual)
	# Info debajo
	var info_y := 240.0
	var name_lbl := _make_label(15, Color(0.95, 0.92, 0.78))
	name_lbl.position = Vector2(12.0, info_y)
	name_lbl.size = Vector2(_detail_panel.size.x - 24.0, 22.0)
	name_lbl.text = _hovered_card.card_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_panel.add_child(name_lbl)
	var meta_lbl := _make_label(11, Color(0.78, 0.78, 0.85))
	meta_lbl.position = Vector2(12.0, info_y + 24.0)
	meta_lbl.size = Vector2(_detail_panel.size.x - 24.0, 16.0)
	meta_lbl.text = "%s · %s · %s" % [
		_type_text(_hovered_card.type),
		_faction_text(_hovered_card.faction),
		_rarity_text(_hovered_card.rarity),
	]
	meta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_panel.add_child(meta_lbl)
	var stats_lbl := _make_label(12, Color(1.0, 0.85, 0.55))
	stats_lbl.position = Vector2(12.0, info_y + 46.0)
	stats_lbl.size = Vector2(_detail_panel.size.x - 24.0, 18.0)
	stats_lbl.text = _stats_text(_hovered_card)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_panel.add_child(stats_lbl)
	var desc_lbl := _make_label(11, Color(0.92, 0.92, 0.95))
	desc_lbl.position = Vector2(12.0, info_y + 72.0)
	desc_lbl.size = Vector2(_detail_panel.size.x - 24.0, _detail_panel.size.y - info_y - 84.0)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.text = _hovered_card.description
	_detail_panel.add_child(desc_lbl)


func _rebuild_grid() -> void:
	for child in _grid_container.get_children():
		child.queue_free()
	var deck := RunState.ensure_deck()
	var heroes: Array[CardData] = []
	var others: Array[CardData] = []
	for c in deck:
		if _active_filter != FILTER_ALL and int(c.faction) != _active_filter:
			continue
		if c.type == CardData.Type.HERO:
			heroes.append(c)
		else:
			others.append(c)

	# Sección héroes
	var heroes_title := _make_label(13, Color(0.85, 0.85, 0.88))
	heroes_title.position = Vector2(0.0, 0.0)
	heroes_title.size = Vector2(_grid_container.size.x, 18.0)
	heroes_title.text = "Héroes (clic = designar líder)"
	heroes_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_container.add_child(heroes_title)

	if heroes.is_empty():
		var no_h := _make_label(11, Color(0.55, 0.58, 0.62))
		no_h.position = Vector2(0.0, 24.0)
		no_h.size = Vector2(_grid_container.size.x, 18.0)
		no_h.text = "(sin héroes en este filtro)"
		_grid_container.add_child(no_h)
	else:
		var heroes_row := _build_card_row(heroes, true)
		heroes_row.position = Vector2(0.0, 24.0)
		_grid_container.add_child(heroes_row)

	# Sección "otras cartas"
	var others_title := _make_label(13, Color(0.85, 0.85, 0.88))
	others_title.position = Vector2(0.0, 220.0)
	others_title.size = Vector2(_grid_container.size.x, 18.0)
	others_title.text = "Otras cartas"
	others_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_container.add_child(others_title)

	if others.is_empty():
		var no_o := _make_label(11, Color(0.55, 0.58, 0.62))
		no_o.position = Vector2(0.0, 244.0)
		no_o.size = Vector2(_grid_container.size.x, 18.0)
		no_o.text = "(sin acciones/efectos en este filtro)"
		_grid_container.add_child(no_o)
	else:
		var others_row := _build_card_row(others, false)
		others_row.position = Vector2(0.0, 244.0)
		_grid_container.add_child(others_row)


func _build_card_row(cards: Array[CardData], clickable: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(CARD_SPACING))
	for c in cards:
		row.add_child(_build_card_entry(c, clickable))
	return row


func _build_card_entry(card: CardData, clickable: bool) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(CARD_W, CARD_H + 22.0)

	var visual := BigCardVisual.new()
	visual.card = card
	visual.w = CARD_W
	visual.h = CARD_H
	container.add_child(visual)

	if card.id == RunState.signature_card_id:
		var marker := _make_label(11, Color(0.95, 0.92, 0.55))
		marker.position = Vector2(0.0, CARD_H + 4.0)
		marker.size = Vector2(CARD_W, 16.0)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.text = "★ LÍDER"
		container.add_child(marker)
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

	# Button transparente para detectar hover + clicks (izq/der)
	var btn := Button.new()
	btn.flat = true
	btn.size = Vector2(CARD_W, CARD_H)
	btn.tooltip_text = "Click derecho: detalle completo" + ("\nClick izquierdo: designar líder" if clickable else "")
	btn.mouse_entered.connect(_on_card_entered.bind(card))
	btn.mouse_exited.connect(_on_card_exited.bind(card))
	btn.gui_input.connect(_on_card_input.bind(card, clickable))
	container.add_child(btn)

	return container


func _on_card_entered(card: CardData) -> void:
	_hovered_card = card
	_refresh_detail_panel()


func _on_card_exited(card: CardData) -> void:
	if _hovered_card == card:
		_hovered_card = null
		_refresh_detail_panel()


func _on_card_input(event: InputEvent, card: CardData, clickable: bool) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_open_card_detail(card)
	elif event.button_index == MOUSE_BUTTON_LEFT and clickable:
		_designate_leader(card)


func _designate_leader(card: CardData) -> void:
	RunState.set_signature(card.id)
	# Refresh: marker + signature label
	_refresh_signature_label()
	_rebuild_grid()


func _open_card_detail(card: CardData) -> void:
	# El modal se agrega como hijo del menu (último child = encima en render)
	var modal := CardDetailModal.new()
	modal.card = card
	add_child(modal)


func _refresh_signature_label() -> void:
	var sig := RunState.get_signature_card()
	if sig != null:
		_signature_label.text = "★ Líder actual: %s" % sig.card_name
	else:
		_signature_label.text = "Sin líder designado — clic en un héroe para elegir uno"


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


# Helpers de texto
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


func _stats_text(card: CardData) -> String:
	if card.type == CardData.Type.HERO:
		return "HP %d   ·   DEF %d" % [card.hp, card.defense]
	return "Reciclaje: %d minerales" % card.recycle_value
