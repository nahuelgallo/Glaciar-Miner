class_name BigCardVisual
extends Node2D

# Visual agrandado de una carta para el modal de detalle, menú de mazo y
# preview. Si la carta tiene `art_path` válida (o existe el placeholder),
# se usa como background con tinte de facción. Sin asset → fallback al
# rect coloreado plano.

const PLACEHOLDER_PATH: String = "res://assets/cards/placeholder.png"

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
	var art := _get_card_art()
	if art != null:
		# Imagen llena toda la carta, después tinte de facción.
		draw_texture_rect(art, rect, false)
		var tint := _faction_color(card.faction)
		tint.a = 0.42
		draw_rect(rect, tint)
	else:
		draw_rect(rect, _faction_color(card.faction))
	# Borde por tipo
	draw_rect(rect, _type_outline_color(card.type), false, maxf(2.0, w * 0.02))
	# Header oscurecido (nombre)
	var header_h: float = maxf(36.0, h * 0.13)
	draw_rect(Rect2(0.0, 0.0, w, header_h), Color(0.0, 0.0, 0.0, 0.55))
	# Banda inferior (stats / type)
	var band_h: float = maxf(50.0, h * 0.20)
	draw_rect(Rect2(0.0, h - band_h, w, band_h), Color(0.05, 0.04, 0.04, 0.88))
	# Texto
	var f := ThemeDB.fallback_font
	if f != null:
		var name_size := int(maxf(14.0, w * 0.085))
		var meta_size := int(maxf(11.0, w * 0.06))
		draw_string(
			f, Vector2(12.0, header_h * 0.65),
			card.card_name, HORIZONTAL_ALIGNMENT_LEFT,
			w - 24.0, name_size, Color.WHITE
		)
		draw_string(
			f, Vector2(12.0, h - band_h + meta_size + 4.0),
			_type_label(), HORIZONTAL_ALIGNMENT_LEFT,
			w - 24.0, meta_size, Color(0.95, 0.85, 0.55)
		)
		draw_string(
			f, Vector2(12.0, h - 12.0),
			_stats_label(), HORIZONTAL_ALIGNMENT_LEFT,
			w - 24.0, meta_size, Color.WHITE
		)


func _get_card_art() -> Texture2D:
	var path: String = card.art_path if not String(card.art_path).is_empty() else PLACEHOLDER_PATH
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


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
