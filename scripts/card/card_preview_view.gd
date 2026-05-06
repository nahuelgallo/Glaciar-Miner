class_name CardPreviewView
extends Node2D

# Panel fijo en el slot de "preview de carta" del mockup. Muestra detalles
# de la carta hovered en la mano: nombre, tipo · facción · rareza, stats
# (HP/DEF para héroes, recycle value para acciones/efectos), descripción.
#
# Coexiste con el drag de la carta: cuando arrastrás, el preview sigue
# mostrando los detalles de la carta arrastrada hasta que la sueltes.

const W: float = 130.0
const H: float = 170.0

var _current_card: CardData

var _name_label: Label
var _type_label: Label
var _stats_label: Label
var _desc_label: Label


func _ready() -> void:
	_build()
	_refresh()


func show_card(card: CardData) -> void:
	_current_card = card
	_refresh()


func clear_card() -> void:
	_current_card = null
	_refresh()


func _draw() -> void:
	var rect := Rect2(0.0, 0.0, W, H)
	if _current_card == null:
		draw_rect(rect, Color(0.13, 0.15, 0.18))
		draw_rect(rect, Color(0.30, 0.32, 0.36), false, 1.5)
		return
	draw_rect(rect, _faction_color(_current_card.faction))
	draw_rect(rect, _type_outline_color(_current_card.type), false, 3.5)
	# Banda inferior para texto sobre fondo oscuro.
	var band := Rect2(0.0, H * 0.55, W, H * 0.45)
	draw_rect(band, Color(0.08, 0.06, 0.05, 0.88))


func _build() -> void:
	_name_label = _make_label(13, Color(0.08, 0.06, 0.03))
	_name_label.position = Vector2(8.0, 6.0)
	_name_label.size = Vector2(W - 16.0, 18.0)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_name_label)

	_type_label = _make_label(10, Color(0.10, 0.08, 0.05))
	_type_label.position = Vector2(8.0, 26.0)
	_type_label.size = Vector2(W - 16.0, 14.0)
	add_child(_type_label)

	_stats_label = _make_label(11, Color(0.95, 0.95, 0.95))
	_stats_label.position = Vector2(8.0, H * 0.55 + 4.0)
	_stats_label.size = Vector2(W - 16.0, 16.0)
	add_child(_stats_label)

	_desc_label = _make_label(10, Color(0.92, 0.92, 0.95))
	_desc_label.position = Vector2(8.0, H * 0.55 + 22.0)
	_desc_label.size = Vector2(W - 16.0, H * 0.45 - 28.0)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_desc_label)


func _make_label(font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _refresh() -> void:
	if _current_card == null:
		_name_label.text = ""
		_type_label.text = ""
		_stats_label.text = ""
		_desc_label.text = "Hover una carta para ver detalles"
		_desc_label.add_theme_color_override("font_color", Color(0.50, 0.53, 0.58))
		_desc_label.position = Vector2(8.0, 8.0)
		_desc_label.size = Vector2(W - 16.0, H - 16.0)
		_desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		queue_redraw()
		return
	# Restaurar layout normal cuando hay carta.
	_desc_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	_desc_label.position = Vector2(8.0, H * 0.55 + 22.0)
	_desc_label.size = Vector2(W - 16.0, H * 0.45 - 28.0)
	_desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	_name_label.text = _current_card.card_name
	_type_label.text = "%s · %s · %s" % [
		_type_text(_current_card.type),
		_faction_text(_current_card.faction),
		_rarity_text(_current_card.rarity),
	]
	if _current_card.type == CardData.Type.HERO:
		var s := "HP %d   DEF %d" % [_current_card.hp, _current_card.defense]
		if _current_card.has_tag(CardData.TAG_LEADER):
			s += "   [LEADER]"
		_stats_label.text = s
	else:
		_stats_label.text = "Reciclaje: %d" % _current_card.recycle_value
	_desc_label.text = _current_card.description
	queue_redraw()


func _faction_color(f: CardData.Faction) -> Color:
	match f:
		CardData.Faction.PERONIST:    return Color(0.55, 0.78, 0.95)
		CardData.Faction.LIBERTARIAN: return Color(0.62, 0.42, 0.85)
		CardData.Faction.MACRIST:     return Color(0.95, 0.85, 0.35)
		CardData.Faction.LEFTIST:     return Color(0.85, 0.30, 0.30)
		CardData.Faction.APOLITICAL:  return Color(0.78, 0.80, 0.82)
		CardData.Faction.OUTSIDER:    return Color(0.28, 0.26, 0.24)
		_:                            return Color(0.85, 0.83, 0.78)


func _type_outline_color(t: CardData.Type) -> Color:
	match t:
		CardData.Type.HERO:    return Color(0.15, 0.10, 0.05)
		CardData.Type.ACTION:  return Color(0.95, 0.85, 0.35)
		CardData.Type.EFFECT:  return Color(0.55, 0.85, 0.65)
	return Color(0.12, 0.09, 0.05)


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
