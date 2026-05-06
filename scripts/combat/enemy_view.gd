class_name EnemyView
extends Node2D

# Visual de un enemigo en el campo. Layout §6.1: nombre, HP, intención.
# Se redibuja a sí mismo escuchando los signals de su EnemyInstance.

const W: float = 150.0
const H: float = 110.0

var data: EnemyInstance

var _name_label: Label
var _hp_label: Label
var _intent_label: Label


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


func _build() -> void:
	_name_label = _make_label(14, Color.WHITE)
	_name_label.position = Vector2(-W * 0.5 + 8.0, -H * 0.5 + 4.0)
	_name_label.size = Vector2(W - 16.0, 20.0)
	add_child(_name_label)

	_hp_label = _make_label(13, Color(1.0, 0.55, 0.55))
	_hp_label.position = Vector2(-W * 0.5 + 8.0, -H * 0.5 + 26.0)
	_hp_label.size = Vector2(W - 16.0, 18.0)
	add_child(_hp_label)

	_intent_label = _make_label(12, Color(1.0, 0.85, 0.55))
	_intent_label.position = Vector2(-W * 0.5 + 8.0, H * 0.5 - 24.0)
	_intent_label.size = Vector2(W - 16.0, 18.0)
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
	_hp_label.text = "HP %d/%d" % [data.hp, data.max_hp]
	if data.is_alive():
		_intent_label.text = "Intención: pegar %d" % data.intent_damage
	else:
		_intent_label.text = "✖ derrotado"
	queue_redraw()


func _on_data_changed(_c: int, _m: int) -> void:
	_refresh()


func _on_intent_changed(_d: int) -> void:
	_refresh()
