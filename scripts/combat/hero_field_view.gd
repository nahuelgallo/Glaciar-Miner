class_name HeroFieldView
extends Node2D

# Visual del héroe invocado en el campo. Distinto de CardView (la carta en
# la mano): acá la carta ya fue jugada y el héroe es un combatiente con HP
# mutable (HeroInstance). Color de fondo = facción de la carta (§8.2).

const W: float = 150.0
const H: float = 110.0

var data: HeroInstance

var _name_label: Label
var _stats_label: Label


func _ready() -> void:
	_build()
	if data != null:
		data.hp_changed.connect(_on_hp_changed)
	_refresh()


func _draw() -> void:
	var rect := Rect2(-W * 0.5, -H * 0.5, W, H)
	draw_rect(rect, _faction_color())
	draw_rect(rect, Color(0.15, 0.10, 0.05), false, 3.0)


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
	_name_label = _make_label(14, Color(0.08, 0.06, 0.03))
	_name_label.position = Vector2(-W * 0.5 + 8.0, -H * 0.5 + 4.0)
	_name_label.size = Vector2(W - 16.0, 20.0)
	add_child(_name_label)

	_stats_label = _make_label(13, Color(0.12, 0.09, 0.05))
	_stats_label.position = Vector2(-W * 0.5 + 8.0, H * 0.5 - 24.0)
	_stats_label.size = Vector2(W - 16.0, 18.0)
	add_child(_stats_label)


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
	_stats_label.text = "HP %d/%d  DEF %d" % [data.hp, data.max_hp, data.defense()]
	queue_redraw()


func _on_hp_changed(_c: int, _m: int) -> void:
	_refresh()
