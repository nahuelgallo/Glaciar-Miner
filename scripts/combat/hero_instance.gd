class_name HeroInstance
extends RefCounted

# Instancia "viva" de una carta de héroe en una run. Mantiene HP actual
# (que persiste entre combates §6.4) separado del HP máximo. La carta
# subyacente (`data`) es inmutable; este objeto es el state mutable.

signal hp_changed(current: int, maximum: int)

var data: CardData
var hp: int
var max_hp: int


func _init(card: CardData) -> void:
	data = card
	max_hp = card.hp
	hp = card.hp


func is_alive() -> bool:
	return hp > 0


func defense() -> int:
	return data.defense


# Aplica un hit siguiendo la regla del §6.4:
#   - damage ≤ defense → daño completo al héroe (absorbido)
#   - damage > defense → overflow = (damage - defense): el héroe recibe
#     el overflow Y el jugador recibe el mismo overflow.
# Devuelve el overflow para que el caller (CombatResolver) lo aplique al
# RunState. No toca RunState directamente: el héroe es testeable en
# aislamiento.
func take_hit(damage: int) -> int:
	if damage <= 0:
		return 0
	var overflow := 0
	var hero_loss := damage
	if damage > defense():
		overflow = damage - defense()
		hero_loss = overflow
	hp = maxi(0, hp - hero_loss)
	hp_changed.emit(hp, max_hp)
	return overflow


func heal(amount: int) -> void:
	if amount <= 0:
		return
	hp = mini(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)


# Reset entre runs (no entre combates: §6.4 dice que el HP carrea).
func reset_to_full() -> void:
	hp = max_hp
	hp_changed.emit(hp, max_hp)
