extends Node2D

# Pantalla de combate. Layout basado en `Referencia/Frame 2(1).png`:
#
#   [Top bar: info jugador · cola próximos turnos · minerales · pausa]
#   [Tutorial?][              Combat log central             ][Dev?]
#   [Heroes col]    [Eye candy placeholder]    [Enemies col]
#   [Mazo+Descarte][Card preview][      Mano      ][Next turn]
#                          [Help footer]
#
# Las áreas marcadas con `?` son placeholders dev/tutorial — punteadas en el
# mockup para indicar "aparecen ocasionalmente".

@onready var _hand: HandManager = $HandManager

# ──────────────────────────────────────────────────────────────────
# CONFIG
# ──────────────────────────────────────────────────────────────────

const HAND_CAP: int = 7
const ENEMY_INTENT_MIN: int = 3
const ENEMY_INTENT_MAX: int = 7
const TURN_QUEUE_PEEK: int = 5

# Posiciones del HUD (1280×720).
const BATTLEFIELD_POS := Vector2(640.0, 350.0)
const COMBAT_LOG_POS := Vector2(240.0, 64.0)
const COMBAT_LOG_SIZE := Vector2(820.0, 102.0)
const TUTORIAL_AREA := Rect2(16.0, 64.0, 200.0, 130.0)
const EYE_CANDY_AREA := Rect2(240.0, 180.0, 820.0, 250.0)
const DEV_AREA := Rect2(1064.0, 64.0, 200.0, 130.0)
const DECK_STACK_POS := Vector2(60.0, 470.0)
const DISCARD_STACK_POS := Vector2(60.0, 590.0)
const CARD_PREVIEW_RECT := Rect2(140.0, 450.0, 160.0, 260.0)
const NEXT_TURN_BUTTON_RECT := Rect2(1110.0, 530.0, 150.0, 60.0)
const PAUSE_BUTTON_RECT := Rect2(1190.0, 12.0, 80.0, 30.0)
const FOOTER_RECT := Rect2(0.0, 700.0, 1280.0, 20.0)

const _MINERAL_HOTKEYS: Dictionary = {
	KEY_1: CardData.Faction.PERONIST,
	KEY_2: CardData.Faction.LIBERTARIAN,
	KEY_3: CardData.Faction.MACRIST,
	KEY_4: CardData.Faction.LEFTIST,
	KEY_5: CardData.Faction.APOLITICAL,
	KEY_6: CardData.Faction.OUTSIDER,
}

const _INTENT_CYCLE: Array[int] = [3, 5, 8, 12]

# ──────────────────────────────────────────────────────────────────
# STATE
# ──────────────────────────────────────────────────────────────────

var _pool: Array[CardData] = []
var _battlefield: Battlefield
var _discard_pile: DiscardPileView
var _drag_arrow: DragArrowOverlay
var _dragging_card: CardData
var _turn_number: int = 1
var _intent_cycle_index: int = 1
var _combat_ended: bool = false
# Mientras se está reproduciendo la secuencia de turnos enemigos, este es
# el enemigo cuyo turno está activo. null = turno del jugador.
var _acting_enemy: EnemyInstance
var _enemy_turn_in_progress: bool = false

# HUD nodes
var _top_info_label: Label
var _minerals_inline: RichTextLabel
var _turn_queue_box: HBoxContainer
var _pause_button: Button
var _next_turn_button: Button
var _combat_log: RichTextLabel
var _deck_count_label: Label
var _card_preview: CardPreviewView
var _help_footer_label: Label


# ──────────────────────────────────────────────────────────────────
# READY / BUILD
# ──────────────────────────────────────────────────────────────────


func _ready() -> void:
	_setup_picking()
	_pool = CardLoader.load_all()
	_build_battlefield()
	_build_hud()
	_connect_run_state()
	_auto_summon_signature()
	_spawn_pending_or_default_enemies()
	_hand.position = Vector2(680.0, 615.0)
	_hand.card_dropped.connect(_on_card_dropped)
	_hand.card_hover_started.connect(_on_hand_card_hover_started)
	_hand.card_hover_ended.connect(_on_hand_card_hover_ended)
	_hand.card_inspect_requested.connect(_open_card_detail_modal)
	_hand.card_drag_started.connect(_on_card_drag_started)
	_hand.card_drag_ended.connect(_on_card_drag_ended)
	if _discard_pile != null:
		_discard_pile.inspect_requested.connect(_open_card_detail_modal)
	if _pool.is_empty():
		push_warning("Main: no hay cartas en el JSON")
	else:
		for i in 5:
			_hand.add_card(_pool.pick_random())
	_refresh_hud()
	# _process se enciende solo cuando hay drag activo (ver _on_card_drag_*).
	set_process(false)


func _setup_picking() -> void:
	var vp := get_viewport()
	vp.physics_object_picking = true
	if "physics_object_picking_sort" in vp:
		vp.physics_object_picking_sort = true
	if "physics_object_picking_first_only" in vp:
		vp.physics_object_picking_first_only = true


func _build_battlefield() -> void:
	_battlefield = Battlefield.new()
	_battlefield.name = "Battlefield"
	_battlefield.position = BATTLEFIELD_POS
	add_child(_battlefield)

	_discard_pile = DiscardPileView.new()
	_discard_pile.name = "DiscardPile"
	_discard_pile.position = DISCARD_STACK_POS
	add_child(_discard_pile)

	_drag_arrow = DragArrowOverlay.new()
	_drag_arrow.name = "DragArrow"
	add_child(_drag_arrow)


func _build_hud() -> void:
	var hud := Control.new()
	hud.name = "Hud"
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.anchor_right = 1.0
	hud.anchor_bottom = 1.0
	add_child(hud)

	_build_top_bar(hud)
	_build_combat_log(hud)
	_build_card_preview(hud)
	_build_deck_count(hud)
	_build_next_turn_button(hud)
	_build_help_footer(hud)
	_build_placeholder_labels(hud)


func _build_placeholder_labels(parent: Control) -> void:
	# Labels descriptivos dentro de las áreas punteadas para que se vea de
	# qué se trata cada zona. El borde punteado lo dibuja el _draw del root.
	var areas := [
		[TUTORIAL_AREA, "Tutorial / ayuda al jugador\n(aparece ocasionalmente)"],
		[EYE_CANDY_AREA, "Eye candy: efectos visuales\nde quien juega ahora"],
		[DEV_AREA, "Dev / debug\n(stats y botones especiales)"],
	]
	for entry in areas:
		var rect: Rect2 = entry[0]
		var text: String = entry[1]
		var lbl := _make_label(11, Color(0.50, 0.53, 0.58))
		lbl.position = rect.position + Vector2(8.0, 8.0)
		lbl.size = rect.size - Vector2(16.0, 16.0)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.text = text
		parent.add_child(lbl)


func _build_top_bar(parent: Control) -> void:
	# Info del jugador (izquierda)
	_top_info_label = _make_label(14, Color(1.0, 0.62, 0.62))
	_top_info_label.position = Vector2(16.0, 14.0)
	_top_info_label.size = Vector2(300.0, 24.0)
	parent.add_child(_top_info_label)

	# Cola de próximos turnos (centro)
	var queue_label := _make_label(11, Color(0.75, 0.78, 0.85))
	queue_label.position = Vector2(330.0, 4.0)
	queue_label.size = Vector2(80.0, 16.0)
	queue_label.text = "Próximos turnos"
	parent.add_child(queue_label)

	_turn_queue_box = HBoxContainer.new()
	_turn_queue_box.position = Vector2(330.0, 18.0)
	_turn_queue_box.add_theme_constant_override("separation", 4)
	parent.add_child(_turn_queue_box)

	# Minerales en formato compacto coloreado (derecha)
	_minerals_inline = RichTextLabel.new()
	_minerals_inline.bbcode_enabled = true
	_minerals_inline.fit_content = true
	_minerals_inline.scroll_active = false
	_minerals_inline.position = Vector2(820.0, 14.0)
	_minerals_inline.size = Vector2(360.0, 26.0)
	_minerals_inline.add_theme_font_size_override("normal_font_size", 12)
	parent.add_child(_minerals_inline)

	# Pausa (placeholder)
	_pause_button = Button.new()
	_pause_button.text = "Pausa"
	_pause_button.position = PAUSE_BUTTON_RECT.position
	_pause_button.size = PAUSE_BUTTON_RECT.size
	_pause_button.pressed.connect(_on_pause_pressed)
	parent.add_child(_pause_button)


func _build_combat_log(parent: Control) -> void:
	_combat_log = RichTextLabel.new()
	_combat_log.bbcode_enabled = true
	_combat_log.scroll_active = true
	_combat_log.scroll_following = true
	_combat_log.position = COMBAT_LOG_POS
	_combat_log.size = COMBAT_LOG_SIZE
	_combat_log.add_theme_color_override("default_color", Color(0.85, 0.85, 0.88))
	_combat_log.add_theme_font_size_override("normal_font_size", 13)
	parent.add_child(_combat_log)


func _build_card_preview(_parent: Control) -> void:
	# Preview view es Node2D (tiene _draw), no Control. Lo agregamos como
	# hijo del root, no del Hud Control. Por default oculto — solo se muestra
	# en hover.
	_card_preview = CardPreviewView.new()
	_card_preview.name = "CardPreview"
	_card_preview.position = CARD_PREVIEW_RECT.position
	_card_preview.hide()
	add_child(_card_preview)


func _build_deck_count(parent: Control) -> void:
	# Counter encima de DECK stack
	var deck_title := _make_label(11, Color(0.85, 0.85, 0.88))
	deck_title.position = Vector2(DECK_STACK_POS.x - 35.0, DECK_STACK_POS.y - 60.0)
	deck_title.size = Vector2(70.0, 16.0)
	deck_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_title.text = "MAZO"
	parent.add_child(deck_title)

	_deck_count_label = _make_label(13, Color(0.95, 0.95, 0.92))
	_deck_count_label.position = Vector2(DECK_STACK_POS.x - 35.0, DECK_STACK_POS.y - 8.0)
	_deck_count_label.size = Vector2(70.0, 16.0)
	_deck_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(_deck_count_label)

	var discard_title := _make_label(11, Color(0.85, 0.85, 0.88))
	discard_title.position = Vector2(DISCARD_STACK_POS.x - 35.0, DISCARD_STACK_POS.y - 60.0)
	discard_title.size = Vector2(70.0, 16.0)
	discard_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discard_title.text = "DESCARTE"
	parent.add_child(discard_title)


func _build_next_turn_button(parent: Control) -> void:
	_next_turn_button = Button.new()
	_next_turn_button.text = "Siguiente\nturno"
	_next_turn_button.position = NEXT_TURN_BUTTON_RECT.position
	_next_turn_button.size = NEXT_TURN_BUTTON_RECT.size
	_next_turn_button.pressed.connect(_end_player_turn)
	parent.add_child(_next_turn_button)


func _build_help_footer(parent: Control) -> void:
	_help_footer_label = _make_label(11, Color(0.55, 0.58, 0.62))
	_help_footer_label.position = FOOTER_RECT.position
	_help_footer_label.size = FOOTER_RECT.size
	_help_footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help_footer_label.text = (
		"Drag = jugar carta · T = siguiente turno · Q = volver a explorar · "
		+ "1-6 = +mineral · K = enemigo ataca · D = pegás 3 · I = ciclar intent · O = toggle héroe · E = respawn"
	)
	parent.add_child(_help_footer_label)


func _make_label(font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


# ──────────────────────────────────────────────────────────────────
# DRAW DEL ROOT (background + áreas placeholder punteadas)
# ──────────────────────────────────────────────────────────────────


func _draw() -> void:
	# Background general (el ColorRect del .tscn fue removido para no tapar
	# este draw; ver insight de orden de render).
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.10, 0.12, 0.16))
	# Top bar background
	draw_rect(Rect2(0.0, 0.0, 1280.0, 50.0), Color(0.16, 0.18, 0.22))
	draw_rect(Rect2(0.0, 50.0, 1280.0, 2.0), Color(0.30, 0.32, 0.35))
	# Footer bar
	draw_rect(Rect2(0.0, 696.0, 1280.0, 24.0), Color(0.16, 0.18, 0.22))
	draw_rect(Rect2(0.0, 694.0, 1280.0, 2.0), Color(0.30, 0.32, 0.35))
	# Áreas placeholder (punteadas, ocasionales según el mockup)
	_draw_dashed_rect(TUTORIAL_AREA, Color(0.55, 0.58, 0.62), "Tutorial / ayuda")
	_draw_dashed_rect(EYE_CANDY_AREA, Color(0.45, 0.48, 0.55), "Eye candy: efectos visuales / turno actual")
	_draw_dashed_rect(DEV_AREA, Color(0.55, 0.58, 0.62), "Dev / debug")
	# (El card preview se dibuja desde CardPreviewView, hijo del root)
	# Deck stack visual (rectángulos apilados)
	_draw_card_stack(DECK_STACK_POS, Color(0.30, 0.34, 0.40))
	# (El descarte se dibuja desde DiscardPileView)


func _draw_dashed_rect(rect: Rect2, color: Color, label: String = "") -> void:
	var dash := 6.0
	var gap := 4.0
	# Top
	var x := rect.position.x
	while x < rect.position.x + rect.size.x:
		var x2 := minf(x + dash, rect.position.x + rect.size.x)
		draw_line(Vector2(x, rect.position.y), Vector2(x2, rect.position.y), color, 1.5)
		x += dash + gap
	# Bottom
	x = rect.position.x
	var by := rect.position.y + rect.size.y
	while x < rect.position.x + rect.size.x:
		var x2 := minf(x + dash, rect.position.x + rect.size.x)
		draw_line(Vector2(x, by), Vector2(x2, by), color, 1.5)
		x += dash + gap
	# Left
	var y := rect.position.y
	while y < rect.position.y + rect.size.y:
		var y2 := minf(y + dash, rect.position.y + rect.size.y)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x, y2), color, 1.5)
		y += dash + gap
	# Right
	y = rect.position.y
	var rx := rect.position.x + rect.size.x
	while y < rect.position.y + rect.size.y:
		var y2 := minf(y + dash, rect.position.y + rect.size.y)
		draw_line(Vector2(rx, y), Vector2(rx, y2), color, 1.5)
		y += dash + gap


func _draw_card_stack(center: Vector2, color: Color) -> void:
	const W := 70.0
	const H := 90.0
	const LAYERS := 4
	for i in range(LAYERS - 1, -1, -1):
		var off := Vector2(float(i) * 1.5, -float(i) * 2.0)
		var rect := Rect2(center.x - W * 0.5 + off.x, center.y - H * 0.5 + off.y, W, H)
		var c := color if i == 0 else color.darkened(0.15 + 0.05 * float(i))
		draw_rect(rect, c)
		draw_rect(rect, Color(0.10, 0.08, 0.06), false, 1.5)


# ──────────────────────────────────────────────────────────────────
# CONNECT / REFRESH
# ──────────────────────────────────────────────────────────────────


func _connect_run_state() -> void:
	RunState.player_hp_changed.connect(_on_player_hp_changed)
	RunState.minerals_changed.connect(_on_minerals_changed)


func _refresh_hud() -> void:
	_on_player_hp_changed(RunState.player_hp, RunState.player_max_hp)
	_refresh_minerals()
	_refresh_turn_queue()
	_refresh_deck_count()
	queue_redraw()


func _on_player_hp_changed(current: int, maximum: int) -> void:
	var alive_heroes: int = 0
	if _battlefield != null:
		for h in _battlefield.heroes():
			if h.is_alive():
				alive_heroes += 1
	_top_info_label.text = "HP %d/%d   ·   Héroes en campo: %d/%d   ·   Turno %d" % [
		current, maximum, alive_heroes, Battlefield.MAX_HEROES, _turn_number
	]


func _on_minerals_changed(_faction: int, _new_amount: int) -> void:
	_refresh_minerals()


func _on_hand_card_hover_started(card: CardData) -> void:
	if _card_preview != null:
		_card_preview.show_card(card)
		_card_preview.show()


func _on_hand_card_hover_ended() -> void:
	if _card_preview != null:
		_card_preview.hide()
		_card_preview.clear_card()


func _open_card_detail_modal(card: CardData) -> void:
	if card == null:
		return
	# Cerramos cualquier modal previo para evitar pilas.
	for child in get_children():
		if child is CardDetailModal:
			child.queue_free()
	var modal := CardDetailModal.new()
	modal.card = card
	add_child(modal)


# Highlight de drop targets + flecha apuntadora durante el drag de una carta.
func _on_card_drag_started(card: CardData, _view: CardView) -> void:
	_dragging_card = card
	_battlefield.set_drop_highlight(card.type, EffectExecutor.target_kind_for(card))
	set_process(true)


func _on_card_drag_ended() -> void:
	_dragging_card = null
	if _battlefield != null:
		_battlefield.clear_drop_highlight()
	if _drag_arrow != null:
		_drag_arrow.clear()
	set_process(false)


func _process(_delta: float) -> void:
	if _dragging_card == null or _drag_arrow == null:
		return
	var mouse := get_global_mouse_position()
	# Origin de la flecha: justo encima del HandManager (la mano), x del mouse.
	var origin := Vector2(mouse.x, _hand.global_position.y - 80.0)
	var targets := _battlefield.slot_positions_for_drop(
		_dragging_card.type,
		EffectExecutor.target_kind_for(_dragging_card),
	)
	_drag_arrow.update_drag(origin, mouse, targets)


func _refresh_minerals() -> void:
	var bb := ""
	for f in CardData.Faction.values():
		if f == CardData.Faction.NONE:
			continue
		var c := _faction_color(f).to_html(false)
		var amt := RunState.minerals.get_amount(f)
		var letter := _faction_letter(f)
		bb += "[color=#%s]%s %d[/color]   " % [c, letter, amt]
	_minerals_inline.text = bb


func _refresh_deck_count() -> void:
	# Hoy "deck" = el pool de cartas disponibles. Cuando exista deck/discard
	# real (M2 del ROADMAP), esto pasa a ser el conteo real del mazo activo.
	_deck_count_label.text = "%d" % _pool.size()


func _refresh_turn_queue() -> void:
	for child in _turn_queue_box.get_children():
		child.queue_free()
	# Construye la secuencia base: VOS + cada enemigo vivo en orden.
	var alive_enemies: Array[EnemyInstance] = []
	if _battlefield != null:
		for e in _battlefield.enemies():
			if e.is_alive():
				alive_enemies.append(e)
	var seq: Array[Dictionary] = []
	seq.append({"label": "VOS", "is_player": true})
	for e in alive_enemies:
		seq.append({"label": e.enemy_name.to_upper(), "is_player": false, "ref": e})
	if seq.is_empty():
		return
	# Si está actuando un enemigo, rotamos la secuencia para que ese sea el
	# primero (el "actual"), seguido de los demás enemigos restantes y
	# después VOS para el próximo turno.
	var start_idx := 0
	if _acting_enemy != null:
		for i in seq.size():
			if seq[i].get("ref") == _acting_enemy:
				start_idx = i
				break
	for k in TURN_QUEUE_PEEK:
		var item: Dictionary = seq[(start_idx + k) % seq.size()]
		var pill := _make_turn_pill(String(item["label"]), bool(item["is_player"]), k == 0)
		_turn_queue_box.add_child(pill)


func _make_turn_pill(text: String, is_player: bool, is_current: bool) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.30, 0.55, 0.32) if is_player else Color(0.55, 0.30, 0.30)
	if is_current:
		sb.bg_color = sb.bg_color.lightened(0.15)
		sb.border_color = Color(0.95, 0.92, 0.55)
		sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.text = text
	panel.add_child(lbl)
	return panel


func _faction_color(f: int) -> Color:
	match f:
		CardData.Faction.PERONIST:    return Color(0.55, 0.78, 0.95)
		CardData.Faction.LIBERTARIAN: return Color(0.78, 0.62, 0.95)
		CardData.Faction.MACRIST:     return Color(0.95, 0.85, 0.35)
		CardData.Faction.LEFTIST:     return Color(0.95, 0.55, 0.55)
		CardData.Faction.APOLITICAL:  return Color(0.85, 0.85, 0.88)
		CardData.Faction.OUTSIDER:    return Color(0.62, 0.58, 0.55)
	return Color.WHITE


func _faction_letter(f: int) -> String:
	match f:
		CardData.Faction.PERONIST:    return "P"
		CardData.Faction.LIBERTARIAN: return "L"
		CardData.Faction.MACRIST:     return "G"
		CardData.Faction.LEFTIST:     return "Z"
		CardData.Faction.APOLITICAL:  return "A"
		CardData.Faction.OUTSIDER:    return "X"
	return "?"


func _log(line: String, color_hex: String = "cccccc") -> void:
	_combat_log.append_text("[color=#%s]%s[/color]\n" % [color_hex, line])


# ──────────────────────────────────────────────────────────────────
# HEROES Y ENEMIGOS
# ──────────────────────────────────────────────────────────────────


# §7.7: auto-summon del signature hero al inicio del combate. Lee
# `RunState.signature_card_id` (designado vía DeckManagementMenu en
# exploración). Fallback: primer HERO del pool si no hay signature.
func _auto_summon_signature() -> void:
	var sig := RunState.get_signature_card()
	if sig != null:
		var hero := RunState.get_or_create_hero(sig)
		if hero.is_alive():
			if _summon_hero_instance(hero):
				_log("Líder %s invocado al inicio del combate (HP %d/%d)." % [
					sig.card_name, hero.hp, hero.max_hp
				], "ddffaa")
				return
		else:
			_log("Líder %s está caído (0 HP). Curalo en un shrine." % sig.card_name, "ff8866")
			return
	# Fallback: primer hero vivo del pool.
	for card in _pool:
		if card.type == CardData.Type.HERO:
			var hero := RunState.get_or_create_hero(card)
			if hero.is_alive():
				_summon_hero_instance(hero)
				return


# §6.4: usa la HeroInstance del roster persistente. La carta se "vuelve a
# poner" en el campo con su HP actual, no se crea fresh.
func _summon_hero_from_card(card: CardData) -> bool:
	if _battlefield == null:
		return false
	var hero := RunState.get_or_create_hero(card)
	if not hero.is_alive():
		return false
	return _summon_hero_instance(hero)


func _summon_hero_instance(hero: HeroInstance) -> bool:
	if _battlefield == null:
		return false
	# Si ya está en el campo (caso reuso), no duplicar.
	for h in _battlefield.heroes():
		if h == hero:
			return true
	return _battlefield.add_hero(hero)


func _spawn_pending_or_default_enemies() -> void:
	if _battlefield == null:
		return
	_battlefield.clear_enemies()
	var spawned := 0
	var ids := RunState.pending_combat_enemy_ids
	if not ids.is_empty():
		var world := RunState.ensure_world()
		for id in ids:
			for enemy_dict in world.enemies:
				if int(enemy_dict["id"]) == id:
					var is_boss: bool = bool(enemy_dict.get("is_boss", false))
					# §5.4 encounter groupings: enemigos comunes spawn en grupo
					# de 1-3 (random). Bosses son siempre 1 (combate único).
					var group_size: int = 1 if is_boss else 1 + randi() % mini(3, Battlefield.MAX_ENEMIES)
					for i in group_size:
						var ei := EnemyInstance.new(
							String(enemy_dict["kind"]),
							int(enemy_dict["max_hp"]),
							int(enemy_dict["intent"]),
							is_boss
						)
						if not _battlefield.add_enemy(ei):
							break  # battlefield lleno
						spawned += 1
					break
	if spawned == 0:
		_battlefield.add_enemy(EnemyInstance.new("Slime", 14, _INTENT_CYCLE[_intent_cycle_index]))


# ──────────────────────────────────────────────────────────────────
# DROP HANDLING (desde la mano)
# ──────────────────────────────────────────────────────────────────


func _on_card_dropped(card: CardData, drop_position: Vector2, view: CardView) -> void:
	if _combat_ended:
		return
	# null = drop inválido. Dict (incluso vacío) = drop válido. Las cartas
	# heal_player y gain_minerals legítimamente devuelven {} porque no
	# necesitan target — distinto de "wrong drop".
	var context: Variant = _build_drop_context(card, drop_position)
	if context == null:
		_log(_drop_invalid_message(card), "ffaa55")
		return
	var result := EffectExecutor.execute(card, context as Dictionary)
	_log(String(result["message"]), "cccccc" if bool(result["ok"]) else "ff8866")
	if bool(result["ok"]):
		# Animación: la carta vuela al descarte, después se remueve y se
		# agrega al pile. El estado de combate ya se aplicó (effect ya corrió).
		var view_ref := view
		var card_ref := card
		var discard_pos := _discard_pile.global_position if _discard_pile != null else view.global_position
		view.play_to(discard_pos, func():
			_hand.remove_view(view_ref)
			if _discard_pile != null:
				_discard_pile.add_card(card_ref)
		)
		_check_combat_outcome()
		_refresh_hud()


# Devuelve null si el drop no es válido para esta carta, o un Dictionary
# (posiblemente vacío) con el context para EffectExecutor si es válido.
func _build_drop_context(card: CardData, drop_position: Vector2) -> Variant:
	var kind := EffectExecutor.target_kind_for(card)
	if card.type == CardData.Type.HERO:
		# HERO requiere precisión: solo sobre un slot de héroe (no cualquier
		# parte del campo). El highlight visual durante el drag muestra los
		# slots disponibles.
		if not _battlefield.is_over_hero_slot(drop_position):
			return null
		if _battlefield.is_full_of_heroes():
			return null
		return { "summon_callback": Callable(self, "_summon_hero_callback") }
	match kind:
		EffectExecutor.TargetKind.ENEMY:
			var enemy := _battlefield.enemy_at(drop_position)
			if enemy == null:
				return null
			# §7.3 synergy: el carrier (hero a través del cual se juega la
			# action card) es el primer hero vivo. Cuando exista UI para
			# elegir carrier explícito, esto cambia.
			return {
				"target_enemy": enemy,
				"carrier_hero": _battlefield.first_alive_hero(),
			}
		EffectExecutor.TargetKind.HERO_SELF:
			var hero := _battlefield.first_alive_hero()
			if hero == null:
				return null
			if not (_battlefield.is_over_hero_slot(drop_position) or _battlefield.is_over_battlefield(drop_position)):
				return null
			return { "active_hero": hero }
		EffectExecutor.TargetKind.NONE, _:
			if not _battlefield.is_over_battlefield(drop_position):
				return null
			return {}
	return null


# Callback que EffectExecutor llama al jugar una HERO. Recibe la CardData
# (no una instancia fresh) para que podamos reusar la HeroInstance del
# roster persistente §6.4. Devuelve bool: false = no se pudo invocar.
func _summon_hero_callback(card: CardData) -> bool:
	return _summon_hero_from_card(card)


func _drop_invalid_message(card: CardData) -> String:
	var kind := EffectExecutor.target_kind_for(card)
	if card.type == CardData.Type.HERO:
		if _battlefield.is_full_of_heroes():
			return "Campo de héroes lleno (3/3). Esperá a que muera uno."
		return "Soltá %s sobre un slot de héroe vacío." % card.card_name
	match kind:
		EffectExecutor.TargetKind.ENEMY:
			return "%s necesita soltarse sobre un enemigo." % card.card_name
		EffectExecutor.TargetKind.HERO_SELF:
			return "%s necesita un héroe activo en el campo." % card.card_name
	return "Soltá %s sobre el campo de combate." % card.card_name


# ──────────────────────────────────────────────────────────────────
# COMBATE: TURNOS Y RESOLUCIÓN
# ──────────────────────────────────────────────────────────────────


func _end_player_turn() -> void:
	if _battlefield == null or _combat_ended or _enemy_turn_in_progress:
		return
	_enemy_turn_in_progress = true
	if _next_turn_button != null:
		_next_turn_button.disabled = true
	# Cada enemigo vivo ejecuta intent (§6.5), uno a la vez con delay para
	# que la cola de turnos se vea avanzar.
	var enemies := _battlefield.enemies()
	var any_acted := false
	for enemy in enemies:
		if not enemy.is_alive():
			continue
		any_acted = true
		_acting_enemy = enemy
		_refresh_turn_queue()
		await get_tree().create_timer(0.45).timeout
		# El estado del juego puede haber cambiado durante el await
		# (e.g., otro effect desencadenó algo).
		if _combat_ended or not enemy.is_alive():
			continue
		var target := _battlefield.first_alive_hero()
		var result := CombatResolver.resolve_enemy_attack(target, enemy.intent_damage)
		_report_enemy_attack(enemy, result)
		_battlefield.remove_dead_heroes()
		_check_combat_outcome()
		if _combat_ended:
			break
	_acting_enemy = null
	# Recalcular intents para el próximo turno.
	for enemy in enemies:
		if enemy.is_alive():
			enemy.set_intent(randi_range(ENEMY_INTENT_MIN, ENEMY_INTENT_MAX))
	if not _combat_ended:
		# Inicio del próximo turno: draw 1 (§6.2).
		_turn_number += 1
		if not _pool.is_empty() and _hand.size() < HAND_CAP:
			_hand.add_card(_pool.pick_random())
		if not any_acted:
			_log("Sin enemigos vivos. Turno %d." % _turn_number, "aabb88")
	_enemy_turn_in_progress = false
	if _next_turn_button != null and not _combat_ended:
		_next_turn_button.disabled = false
	_refresh_hud()


func _enemy_executes_intent() -> void:
	if _combat_ended or _battlefield == null:
		return
	var enemy := _battlefield.first_alive_enemy()
	if enemy == null:
		_log("No hay enemigos vivos.", "aaaaaa")
		return
	var target := _battlefield.first_alive_hero()
	var result := CombatResolver.resolve_enemy_attack(target, enemy.intent_damage)
	_report_enemy_attack(enemy, result)
	_battlefield.remove_dead_heroes()
	_check_combat_outcome()
	_refresh_hud()


func _player_attacks_enemy(damage: int) -> void:
	if _combat_ended or _battlefield == null:
		return
	var enemy := _battlefield.first_alive_enemy()
	if enemy == null:
		_log("No hay enemigos vivos para atacar.", "aaaaaa")
		return
	var result := CombatResolver.resolve_player_attack(enemy, damage)
	_report_player_attack(enemy, result)
	_check_combat_outcome()
	_refresh_hud()


func _report_enemy_attack(enemy: EnemyInstance, result: Dictionary) -> void:
	var incoming: int = int(result["incoming_damage"])
	if result["target"] == null:
		_log("[b]%s[/b] pega %d → SIN HÉROE → vos recibís %d (×2)" % [
			enemy.enemy_name, incoming, int(result["player_damage"])
		], "ff8866")
		return
	var hero: HeroInstance = result["target"]
	var line := "[b]%s[/b] pega %d → %s recibe %d" % [
		enemy.enemy_name, incoming, hero.data.card_name, int(result["hero_damage"])
	]
	if int(result["player_damage"]) > 0:
		line += "  ·  overflow al jugador: %d" % int(result["player_damage"])
	if bool(result["hero_died"]):
		line += "  ·  ✖ %s caído" % hero.data.card_name
	_log(line, "ffbb88")


func _report_player_attack(enemy: EnemyInstance, result: Dictionary) -> void:
	var line := "Vos pegás %d → %s recibe %d" % [
		int(result["incoming_damage"]),
		enemy.enemy_name,
		int(result["enemy_damage"]),
	]
	if bool(result["enemy_died"]):
		line += "  ·  ✖ derrotado"
	_log(line, "88dd99")


# ──────────────────────────────────────────────────────────────────
# OUTCOME
# ──────────────────────────────────────────────────────────────────


func _check_combat_outcome() -> void:
	if _combat_ended:
		return
	if RunState.is_dead():
		_trigger_defeat()
		return
	var enemies := _battlefield.enemies()
	if enemies.is_empty():
		return
	for e in enemies:
		if e.is_alive():
			return
	_trigger_victory()


func _trigger_victory() -> void:
	_combat_ended = true
	var world := RunState.ensure_world()
	var msg := "[b]VICTORIA[/b]. Drops:"
	var any_drop := false
	var boss_killed := false
	for id in RunState.pending_combat_enemy_ids:
		for enemy_dict in world.enemies:
			if int(enemy_dict["id"]) == id:
				var f: int = int(enemy_dict["faction"])
				# Mineral drop: bosses dan más, también del mineral de su facción
				var amt: int = 2 + randi() % 3
				if bool(enemy_dict.get("is_boss", false)):
					boss_killed = true
					amt += 5  # bonus boss
				if f != CardData.Faction.NONE:
					RunState.gain_minerals(f, amt)
					msg += "  +%d %s" % [amt, MineralBag.mineral_name(f)]
					any_drop = true
				break
	if not any_drop:
		msg += "  (sin minerales)"
	_log(msg, "88dd99")
	# §6.8: matar al boss dropea McGuffin (§5.3) que abre el hard gate.
	if boss_killed:
		RunState.grant_mcguffin()
		_log("[b]★ McGuffin obtenido[/b] — abre el hard gate de la capa actual.", "ffdd66")
		# Si era el boss de la última capa, marcar run_won
		if RunState.current_layer >= WorldState.MAX_LAYERS:
			RunState.run_won = true
			_log("[b]🎉 Última capa derrotada — RUN GANADA[/b]", "ffdd66")
	# §7.7: si el signature murió durante el combate, forzar re-designar.
	_check_signature_redesignation()
	_log("Apretá [b]Q[/b] para volver a explorar.", "ddffaa")
	RunState.last_combat_outcome = RunState.CombatOutcome.VICTORY


func _check_signature_redesignation() -> void:
	if RunState.signature_card_id == &"":
		return
	var sig := RunState.get_signature_card()
	if sig == null:
		return
	var hero := RunState.get_or_create_hero(sig)
	if not hero.is_alive():
		RunState.must_redesignate_signature = true
		_log("★ Líder %s cayó. Tenés que designar uno nuevo antes de seguir." % sig.card_name, "ffaa55")


func _trigger_defeat() -> void:
	_combat_ended = true
	_log("[b]DERROTADO.[/b] Apretá Q para reiniciar la run.", "ff6666")
	RunState.last_combat_outcome = RunState.CombatOutcome.DEFEAT


func _return_to_exploration() -> void:
	if not _combat_ended:
		RunState.last_combat_outcome = RunState.CombatOutcome.ABORTED
	get_tree().change_scene_to_file("res://scenes/exploration/exploration.tscn")


# ──────────────────────────────────────────────────────────────────
# UI ACTIONS
# ──────────────────────────────────────────────────────────────────


func _on_pause_pressed() -> void:
	for child in get_children():
		if child is PauseMenu:
			return  # ya hay un menú abierto
	var menu := PauseMenu.new()
	menu.restart_requested.connect(_on_pause_restart_requested)
	menu.back_to_exploration_requested.connect(_return_to_exploration)
	add_child(menu)


func _on_pause_restart_requested() -> void:
	RunState.reset_run()
	_return_to_exploration()


func _toggle_active_hero() -> void:
	if _battlefield == null:
		return
	if _battlefield.heroes().size() > 0:
		_battlefield.clear_heroes()
		return
	_auto_summon_signature()


func _cycle_enemy_intent() -> void:
	var enemy := _battlefield.first_alive_enemy() if _battlefield != null else null
	if enemy == null:
		return
	_intent_cycle_index = (_intent_cycle_index + 1) % _INTENT_CYCLE.size()
	enemy.set_intent(_INTENT_CYCLE[_intent_cycle_index])
	_refresh_hud()


# ──────────────────────────────────────────────────────────────────
# INPUT (atajos de testing)
# ──────────────────────────────────────────────────────────────────


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _MINERAL_HOTKEYS.has(event.keycode):
		RunState.gain_minerals(_MINERAL_HOTKEYS[event.keycode], 2)
		return
	match event.keycode:
		KEY_SPACE:
			if not _pool.is_empty() and _hand.size() < HAND_CAP:
				_hand.add_card(_pool.pick_random())
		KEY_BACKSPACE:
			if _hand.size() > 0:
				_hand.remove_card(_hand.size() - 1)
		KEY_R:
			while _hand.size() > 0:
				_hand.remove_card(0)
			for i in 5:
				_hand.add_card(_pool.pick_random())
		KEY_N:
			RunState.damage_player(3)
		KEY_H:
			RunState.heal_player(3)
		KEY_K:
			_enemy_executes_intent()
		KEY_D:
			_player_attacks_enemy(3)
		KEY_I:
			_cycle_enemy_intent()
		KEY_O:
			_toggle_active_hero()
		KEY_E:
			_spawn_pending_or_default_enemies()
			_refresh_hud()
		KEY_T:
			_end_player_turn()
		KEY_Q:
			_return_to_exploration()
