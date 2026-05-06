class_name BigCardVisual
extends Node2D

# Visual agrandado de una carta para el modal de detalle. Layout idéntico al
# CardPreviewView pero con tamaño parametrizable.

var card: CardData
var w: float = 240.0
var h: float = 360.0


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(0.0, 0.0, w, h)
	if card == null:
		draw_rect(rect, Color(0.2, 0.2, 0.2))
		return
	draw_rect(rect, _faction_color(card.faction))
	draw_rect(rect, _type_outline_color(card.type), false, 5.0)
	# Banda inferior con espacio para nombre grande
	var band := Rect2(0.0, h - 80.0, w, 80.0)
	draw_rect(band, Color(0.08, 0.06, 0.05, 0.88))
	# Header con nombre arriba
	var header := Rect2(0.0, 0.0, w, 50.0)
	draw_rect(header, Color(0.0, 0.0, 0.0, 0.30))
	# Texto nombre arriba
	var f := ThemeDB.fallback_font
	if f != null:
		draw_string(f, Vector2(12.0, 30.0), card.card_name, HORIZONTAL_ALIGNMENT_LEFT, w - 24.0, 18, Color.WHITE)
		# Tipo en la banda inferior
		draw_string(f, Vector2(12.0, h - 50.0), _type_label(), HORIZONTAL_ALIGNMENT_LEFT, w - 24.0, 14, Color(0.95, 0.85, 0.55))
		# Stats en la banda inferior
		draw_string(f, Vector2(12.0, h - 26.0), _stats_label(), HORIZONTAL_ALIGNMENT_LEFT, w - 24.0, 14, Color.WHITE)


func _type_label() -> String:
	match card.type:
		CardData.Type.HERO:   return "HÉROE"
		CardData.Type.ACTION: return "ACCIÓN"
		CardData.Type.EFFECT: return "EFECTO"
	return ""


func _stats_label() -> String:
	if card.type == CardData.Type.HERO:
		return "HP %d   DEF %d" % [card.hp, card.defense]
	return "Reciclaje %d" % card.recycle_value


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
