class_name HeroFieldView
extends Node2D

# Visual del héroe invocado en el campo. Distinto de CardView (la carta en
# la mano): acá la carta ya fue jugada y el héroe es un combatiente con HP
# mutable (HeroInstance). Color de fondo = facción de la carta (§8.2).
#
# El layout matchea el mockup: nombre arriba, "USOS: x/y" (HP/MaxHP), barra
# de salud abajo del rect.

const W: float = 130.0
const H: float = 90.0

var data: HeroInstance

var _name_label: Label
var _uses_label: Label
var _def_label: Label


func _ready() -> void:
	_build()
	if data != null:
		data.hp_changed.connect(_on_hp_changed)
	_refresh()


func _draw() -> void:
	var rect := Rect2(-W * 0.5, -H * 0.5, W, H)
	draw_rect(rect, _faction_color())
	draw_rect(rect, Color(0.15, 0.10, 0.05), false, 3.0)
	# Barra de salud bajo el rect.
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


func _faction_color() -> Color:
	if data == null:
		return Color(0.7, 0.68, 0.62)
	match data.data.faction:
		CardData.Faction.PERONIST:    return Color(0.55, 0.78, 0.95)
		CardData.Faction.LIBERTARIAN: return Color(0.62, 0.42, 0.85)
		CardData.Faction.MACRIST:     return Color(0.95, 0.85, 0.35)
		CardData.Faction.LEFTIST:     return Color(0.85, 0.30, 0.30)
		CardData.Faction.APOLITICAL:  return Color(0.78, 0.80, 0.82)
		CardData.Faction.OUTSIDER:    return Color(0.28, 0.26, 0.24)
		_:                            return Color(0.85, 0.83, 0.78)


func _build() -> void:
	_name_label = _make_label(13, Color(0.08, 0.06, 0.03))
	_name_label.position = Vector2(-W * 0.5 + 6.0, -H * 0.5 + 4.0)
	_name_label.size = Vector2(W - 12.0, 18.0)
	add_child(_name_label)

	_uses_label = _make_label(11, Color(0.10, 0.08, 0.04))
	_uses_label.position = Vector2(-W * 0.5 + 6.0, -H * 0.5 + 24.0)
	_uses_label.size = Vector2(W - 12.0, 16.0)
	add_child(_uses_label)

	_def_label = _make_label(11, Color(0.10, 0.08, 0.04))
	_def_label.position = Vector2(-W * 0.5 + 6.0, H * 0.5 - 22.0)
	_def_label.size = Vector2(W - 12.0, 16.0)
	add_child(_def_label)


func _make_label(font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _refresh() -> void:
	if data == null:
		return
	_name_label.text = data.data.card_name
	_uses_label.text = "HP %d/%d" % [data.hp, data.max_hp]
	_def_label.text = "DEF %d" % data.defense()
	queue_redraw()


func _on_hp_changed(_c: int, _m: int) -> void:
	_refresh()
