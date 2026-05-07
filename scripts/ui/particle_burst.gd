class_name ParticleBurst
extends Node2D

# Burst de partículas que explotan desde un punto, cada una en una dirección
# random con velocidad propia. Cycle entre las texturas pasadas. Self-destructs.
# Uso: ParticleBurst.spawn_at(parent, world_pos, [tex1, tex2, ...], count)

const DEFAULT_COUNT: int = 12
const DURATION: float = 0.75
const MIN_SPEED: float = 90.0
const MAX_SPEED: float = 240.0

var textures: Array[Texture2D] = []
var _time: float = 0.0
# { dir: Vector2, speed: float, scale: float, tex_idx: int }
var _particles: Array[Dictionary] = []


static func spawn_at(parent: Node, pos: Vector2, texs: Array[Texture2D], count: int = DEFAULT_COUNT) -> ParticleBurst:
	var burst := ParticleBurst.new()
	burst.textures = texs
	burst.position = pos
	burst.z_index = 150
	parent.add_child(burst)
	burst._init_particles(count)
	return burst


func _init_particles(count: int) -> void:
	for i in count:
		var angle: float = randf() * TAU
		var speed: float = randf_range(MIN_SPEED, MAX_SPEED)
		var scale: float = randf_range(0.7, 1.3)
		var tex_idx: int = i % maxi(1, textures.size())
		_particles.append({
			"dir": Vector2.from_angle(angle),
			"speed": speed,
			"scale": scale,
			"tex_idx": tex_idx,
		})


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _time >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if textures.is_empty() or _particles.is_empty():
		return
	# Alpha fade en los últimos 40%
	var alpha: float = 1.0 - smoothstep(0.6, 1.0, _time / DURATION)
	# Las partículas también se ralentizan: ease out
	var motion_t: float = 1.0 - pow(1.0 - _time / DURATION, 2.0)
	for p in _particles:
		var dir: Vector2 = p["dir"]
		var speed: float = float(p["speed"])
		var dist: float = speed * motion_t * DURATION
		var pos: Vector2 = dir * dist
		var tex: Texture2D = textures[int(p["tex_idx"])]
		var scale: float = float(p["scale"])
		var size: Vector2 = Vector2(tex.get_size()) * scale
		draw_texture_rect(tex, Rect2(pos - size * 0.5, size), false, Color(1.0, 1.0, 1.0, alpha))
