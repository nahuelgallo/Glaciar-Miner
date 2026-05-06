class_name EnemyView
extends Node2D

# Visual de un enemigo en el campo. Layout §6.1: nombre, HP, intención.
# Se redibuja a sí mismo escuchando los signals de su EnemyInstance.

const W: float = 130.0
const H: float = 90.0

var data: EnemyInstance

var _name_label: Label
var _intent_label: Label
var _hp_text: Label


func _ready() -> void:
	_build()
	if data != null:
		data.hp_changed.connect(_on_data_changed)
		data.intent_changed.connect(_on_intent_changed)
	_refresh()


func _draw() -> void:
	var rect := Rect2(-W * 0.5, -H * 0.5, W, H)
	var alive := data != null and data.is_alive()
	var fill := Color(0.42, 0.36, 0.32) if alive else Color(0.18, 0.16, 0.15)
	draw_rect(rect, fill)
	draw_rect(rect, Color(0.85, 0.55, 0.35), false, 3.0)
	# Barra de salud horizontal debajo del rect.
	if data != null and data.max_hp > 0:
		var bar_w := W
		var bar_h := 6.0
		var bar_y := H * 0.5 + 3.0
		var bg_rect := Rect2(-bar_w * 0.5, bar_y, bar_w, bar_h)
		draw_rect(bg_rect, Color(0.15, 0.12, 0.10))
		var ratio: float = clampf(float(data.hp) / float(data.max_hp), 0.0, 1.0)
		var fg_rect := Rect2(-bar_w * 0.5, bar_y, bar_w * ratio, bar_h)
		var bar_color := Color(0.30, 0.85, 0.40) if ratio > 0.5 else (Color(0.95, 0.85, 0.30) if ratio > 0.25 else Color(0.95, 0.30, 0.30))
		draw_rect(fg_rect, bar_color)


func _build() -> void:
	_name_label = _make_label(13, Color.WHITE)
	_name_label.position = Vector2(-W * 0.5 + 6.0, -H * 0.5 + 4.0)
	_name_label.size = Vector2(W - 12.0, 18.0)
	add_child(_name_label)

	_hp_text = _make_label(11, Color(1.0, 0.78, 0.78))
	_hp_text.position = Vector2(-W * 0.5 + 6.0, -H * 0.5 + 24.0)
	_hp_text.size = Vector2(W - 12.0, 16.0)
	add_child(_hp_text)

	_intent_label = _make_label(11, Color(1.0, 0.85, 0.55))
	_intent_label.position = Vector2(-W * 0.5 + 6.0, H * 0.5 - 22.0)
	_intent_label.size = Vector2(W - 12.0, 16.0)
	add_child(_intent_label)


func _make_label(font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _refresh() -> void:
	if data == null:
		return
	_name_label.text = data.enemy_name
	_hp_text.text = "HP %d/%d" % [data.hp, data.max_hp]
	if data.is_alive():
		_intent_label.text = "Intención: %d" % data.intent_damage
	else:
		_intent_label.text = "✖ caído"
	queue_redraw()


func _on_data_changed(_c: int, _m: int) -> void:
	_refresh()


func _on_intent_changed(_d: int) -> void:
	_refresh()
