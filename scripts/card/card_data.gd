class_name CardData
extends RefCounted

enum Type { HERO, ACTION, EFFECT }

# Las 6 facciones del GDD §7.2. NONE = neutral / sin facción
# (las cartas Effect son faction-neutral según §7.3).
enum Faction {
	NONE,
	PERONIST,     # celeste — leader-gated, sustain grupal (§7.2.1)
	LIBERTARIAN,  # violeta — burn / shutdown / glass cannons (§7.2.2)
	MACRIST,      # amarillo — costos diferidos en combate (§7.2.3)
	LEFTIST,      # rojo — escalado lento por estado del campo, FIT (§7.2.4)
	APOLITICAL,   # gris claro — vainilla, FTUE filler (§7.2.5)
	OUTSIDER      # gris carbón — power spikes con costos run-persistentes (§7.2.6)
}

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

# Tag impreso en el tope de ciertas cartas peronistas. Otras cartas peronistas
# leen condiciones tipo "Mientras un [LEADER] esté en el campo, ...". Es
# metadata pura, no un sistema nuevo (disciplina del §7.2).
const TAG_LEADER := &"LEADER"

var id: StringName
var card_name: String
var type: Type
var faction: Faction = Faction.NONE
var rarity: Rarity = Rarity.COMMON
var hp: int = 0
var defense: int = 0
# Minerales que rinde al destruirse en un shrine (§7.5). Más rara = más rinde.
var recycle_value: int = 1
var tags: Array[StringName] = []
var description: String = ""
var art_path: String = ""
# Vocabulario composable §9. Dict con `kind` + params específicos del kind.
# Ej: {"kind": "deal_damage", "amount": 2}, {"kind": "gain_minerals",
# "faction": "APOLITICAL", "amount": 2}. Las HERO no usan effect: jugarlas
# dispara la invocación al campo, no un efecto del vocabulario.
var effect: Dictionary = {}


static func from_dict(d: Dictionary) -> CardData:
	var c := CardData.new()
	c.id = StringName(d.get("id", ""))
	c.card_name = d.get("name", "")
	c.type = Type.get(String(d.get("type", "ACTION")).to_upper(), Type.ACTION)
	c.faction = Faction.get(String(d.get("faction", "NONE")).to_upper(), Faction.NONE)
	c.rarity = Rarity.get(String(d.get("rarity", "COMMON")).to_upper(), Rarity.COMMON)
	c.hp = int(d.get("hp", 0))
	c.defense = int(d.get("defense", 0))
	c.recycle_value = int(d.get("recycle_value", 1))
	var raw_tags: Array = d.get("tags", [])
	c.tags.clear()
	for t in raw_tags:
		c.tags.append(StringName(String(t).to_upper()))
	c.description = d.get("description", "")
	c.art_path = d.get("art_path", "")
	var raw_effect: Variant = d.get("effect", {})
	c.effect = raw_effect if raw_effect is Dictionary else {}
	return c


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)
