class_name CardTooltip
extends Node2D

const PANEL_WIDTH: float = 240.0
const PANEL_HEIGHT: float = 124.0
const PADDING: float = 12.0

var _name_label: Label
var _type_label: Label
var _desc_label: Label
var _stats_label: Label


func _ready() -> void:
	z_index = 100  # siempre por encima de las cartas
	_build()
	hide()


func _draw() -> void:
	var rect := Rect2(0.0, 0.0, PANEL_WIDTH, PANEL_HEIGHT)
	draw_rect(rect, Color(0.08, 0.10, 0.14, 0.95))
	draw_rect(rect, Color(0.85, 0.78, 0.55), false, 2.0)


func show_for(card: CardData) -> void:
	if card == null:
		return
	_name_label.text = card.card_name
	_type_label.text = _type_text(card)
	_desc_label.text = card.description
	_stats_label.text = _stats_text(card)
	show()


func _build() -> void:
	_name_label = _make_label(15, Color.WHITE)
	_name_label.position = Vector2(PADDING, PADDING)
	_name_label.size = Vector2(PANEL_WIDTH - PADDING * 2.0, 20.0)
	add_child(_name_label)

	_type_label = _make_label(11, Color(0.72, 0.72, 0.78))
	_type_label.position = Vector2(PADDING, PADDING + 22.0)
	_type_label.size = Vector2(PANEL_WIDTH - PADDING * 2.0, 16.0)
	add_child(_type_label)

	_desc_label = _make_label(12, Color(0.92, 0.92, 0.92))
	_desc_label.position = Vector2(PADDING, PADDING + 42.0)
	_desc_label.size = Vector2(PANEL_WIDTH - PADDING * 2.0, 44.0)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_desc_label)

	_stats_label = _make_label(11, Color(0.85, 0.78, 0.55))
	_stats_label.position = Vector2(PADDING, PANEL_HEIGHT - PADDING - 14.0)
	_stats_label.size = Vector2(PANEL_WIDTH - PADDING * 2.0, 16.0)
	add_child(_stats_label)


func _make_label(font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _type_text(card: CardData) -> String:
	var type_str := ""
	match card.type:
		CardData.Type.HERO:
			type_str = "Héroe"
		CardData.Type.ACTION:
			type_str = "Acción"
		CardData.Type.EFFECT:
			type_str = "Efecto"
	return "%s · %s · %s" % [type_str, _faction_text(card.faction), _rarity_text(card.rarity)]


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
		var s := "HP %d   Defensa %d" % [card.hp, card.defense]
		if card.has_tag(CardData.TAG_LEADER):
			s += "   [LEADER]"
		return s
	# Para acciones/efectos mostramos el recycle value (lo que rinde en shrines).
	return "Reciclaje: %d" % card.recycle_value
