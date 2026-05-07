class_name EffectAnimation
extends Node2D

# Animación one-shot que muestra una textura agrandándose y desvaneciéndose
# en un punto del campo. Se auto-destruye al terminar.
# Uso: EffectAnimation.spawn_at(parent, world_pos, texture, scale_factor)

var texture: Texture2D
var size_factor: float = 1.0
var duration: float = 0.55

var _time: float = 0.0


static func spawn_at(parent: Node, pos: Vector2, tex: Texture2D, scale_factor: float = 1.0) -> EffectAnimation:
	var anim := EffectAnimation.new()
	anim.texture = tex
	anim.size_factor = scale_factor
	anim.position = pos
	anim.z_index = 150
	parent.add_child(anim)
	return anim


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _time >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if texture == null:
		return
	var t: float = _time / duration
	# Scale rampa: chico → grande
	var s: float = lerpf(0.4, 1.6, t) * size_factor
	# Alpha fade en los últimos 50%
	var alpha: float = 1.0 - smoothstep(0.5, 1.0, t)
	var tex_size: Vector2 = Vector2(texture.get_size()) * s
	draw_texture_rect(texture, Rect2(-tex_size * 0.5, tex_size), false, Color(1.0, 1.0, 1.0, alpha))
