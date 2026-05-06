class_name MineralBag
extends RefCounted

# Bolsa de minerales del jugador. Currency principal del juego (§7.2 / §7.5).
# Cada facción tiene su mineral nombrado in-world:
#   PERONIST    → Peronite
#   LIBERTARIAN → Liberalite
#   MACRIST     → Globite
#   LEFTIST     → Zurdite
#   APOLITICAL  → Argentite
#   OUTSIDER    → Xenite
# Faction.NONE no tiene mineral asociado: las cartas de efecto neutrales (§7.3)
# no producen mineral propio; cuando dropean, dropean el mineral del enemigo
# o de la roca de origen.

var _balances: Dictionary = {}


func _init() -> void:
	for f in CardData.Faction.values():
		if f == CardData.Faction.NONE:
			continue
		_balances[f] = 0


func get_amount(faction: CardData.Faction) -> int:
	return int(_balances.get(faction, 0))


func gain(faction: CardData.Faction, amount: int) -> void:
	if amount <= 0 or faction == CardData.Faction.NONE:
		return
	_balances[faction] = get_amount(faction) + amount


func try_spend(faction: CardData.Faction, amount: int) -> bool:
	if amount <= 0 or faction == CardData.Faction.NONE:
		return false
	if get_amount(faction) < amount:
		return false
	_balances[faction] = get_amount(faction) - amount
	return true


func total() -> int:
	var t := 0
	for v in _balances.values():
		t += int(v)
	return t


func clear() -> void:
	for f in _balances.keys():
		_balances[f] = 0


# Nombre in-world del mineral de la facción (§7.2).
static func mineral_name(faction: CardData.Faction) -> String:
	match faction:
		CardData.Faction.PERONIST:    return "Peronite"
		CardData.Faction.LIBERTARIAN: return "Liberalite"
		CardData.Faction.MACRIST:     return "Globite"
		CardData.Faction.LEFTIST:     return "Zurdite"
		CardData.Faction.APOLITICAL:  return "Argentite"
		CardData.Faction.OUTSIDER:    return "Xenite"
	return ""
