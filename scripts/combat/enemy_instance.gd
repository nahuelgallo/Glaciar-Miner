class_name EnemyInstance
extends RefCounted

# Instancia de un enemigo en combate. Análogo a HeroInstance pero del lado
# enemigo. Los enemigos no tienen Defensa en el GDD (§6.5: solo telegrafían
# intent y hacen una acción por turno). El daño que reciben se resta directo.

signal hp_changed(current: int, maximum: int)
signal intent_changed(damage: int)

var enemy_name: String = "Slime"
var hp: int
var max_hp: int
# §6.5: las intenciones se telegrafían (StS-style) para que el jugador pueda
# planear la defensa. intent_damage = lo que va a hacer en su próximo turno.
var intent_damage: int = 4
# §6.8: los bosses tienen HP elevado, intent más fuerte y dropean un McGuffin.
# Un solo enemigo en un encounter (no 1-3 del grouping §5.4).
var is_boss: bool = false


func _init(name_: String = "Slime", starting_hp: int = 14, intent: int = 4, boss: bool = false) -> void:
	enemy_name = name_
	hp = starting_hp
	max_hp = starting_hp
	intent_damage = intent
	is_boss = boss


func is_alive() -> bool:
	return hp > 0


# Aplica daño directo (sin overflow ni absorción — los enemigos no tienen
# Defensa en el modelo del GDD). Devuelve cuánto se restó realmente, capeado
# al HP restante.
func take_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	var actual := mini(amount, hp)
	hp -= actual
	hp_changed.emit(hp, max_hp)
	return actual


func set_intent(damage: int) -> void:
	intent_damage = maxi(0, damage)
	intent_changed.emit(intent_damage)


func reset_to_full() -> void:
	hp = max_hp
	hp_changed.emit(hp, max_hp)
