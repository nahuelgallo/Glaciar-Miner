class_name PlayerView
extends Node2D

# Visual del Minero (el jugador) en el campo. Distinto de los HeroFieldView:
# representa al jugador mismo, con su HP global de run (§6.6). Posicionado
# como columna propia a la izquierda de los slots de héroes.
#
# Visualmente más alto que un slot de héroe para que se distinga como "vos"
# y no se confunda con un héroe invocado.

const W: float = 130.0
const H: float = 150.0

var _name_label: Label
var _subtitle_label: Label
var _hp_label: Label


func _ready() -> void:
	_build()
	_refresh()
	RunState.player_hp_changed.connect(_on_hp_changed)


func _exit_tree() -> void:
	if RunState != null and RunState.player_hp_changed.is_connected(_on_hp_changed):
		RunState.player_hp_changed.disconnect(_on_hp_changed)


func _draw() -> void:
	var rect := Rect2(-W * 0.5, -H * 0.5, W, H)
	# Color del minero: azul-grisáceo, claramente distinto a las facciones.
	draw_rect(rect, Color(0.28, 0.42, 0.62))
	draw_rect(rect, Color(0.85, 0.92, 0.98), false, 3.5)
	# Banda inferior con HP en grande
	var band := Rect2(-W * 0.5, H * 0.5 - 36.0, W, 36.0)
	draw_rect(band, Color(0.10, 0.14, 0.20, 0.88))
	# Barra de salud bajo el rect
	if RunState.player_max_hp > 0:
		var bar_y := H * 0.5 + 3.0
		var bg_rect := Rect2(-W * 0.5, bar_y, W, 6.0)
		draw_rect(bg_rect, Color(0.15, 0.12, 0.10))
		var ratio: float = clampf(float(RunState.player_hp) / float(RunState.player_max_hp), 0.0, 1.0)
		var fg_rect := Rect2(-W * 0.5, bar_y, W * ratio, 6.0)
		var bar_color := Color(0.30, 0.85, 0.40) if ratio > 0.5 else (Color(0.95, 0.85, 0.30) if ratio > 0.25 else Color(0.95, 0.30, 0.30))
		draw_rect(fg_rect, bar_color)


func _build() -> void:
	_name_label = _make_label(14, Color(0.95, 0.97, 1.0))
	_name_label.position = Vector2(-W * 0.5 + 6.0, -H * 0.5 + 8.0)
	_name_label.size = Vector2(W - 12.0, 20.0)
	_name_label.text = "MINERO"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name_label)

	_subtitle_label = _make_label(10, Color(0.70, 0.78, 0.90))
	_subtitle_label.position = Vector2(-W * 0.5 + 6.0, -H * 0.5 + 28.0)
	_subtitle_label.size = Vector2(W - 12.0, 14.0)
	_subtitle_label.text = "(vos)"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_subtitle_label)

	_hp_label = _make_label(15, Color(1.0, 0.82, 0.82))
	_hp_label.position = Vector2(-W * 0.5 + 6.0, H * 0.5 - 30.0)
	_hp_label.size = Vector2(W - 12.0, 22.0)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hp_label)


func _make_label(font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _refresh() -> void:
	_hp_label.text = "HP %d/%d" % [RunState.player_hp, RunState.player_max_hp]
	queue_redraw()


func _on_hp_changed(_c: int, _m: int) -> void:
	_refresh()
