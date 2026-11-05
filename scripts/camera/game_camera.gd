class_name GameCamera
extends Camera3D
## Mobile action camera: follows the local hero with look-ahead (movement + aim), smooth zoom,
## trauma-based screen shake (h/v offsets + roll, so aiming math is unaffected) and an intro fly-in.
## Red team sees the arena rotated 180 degrees so everyone attacks "to the right".

const OFFSET := Vector3(0, 13.6, 7.8)
const BOUNDS := Vector2(15.5, 9.5)

var target: Node3D
var flip := 1.0
var lead := Vector3.ZERO           # set every frame by the match view
var zoom := 1.0
var target_zoom := 1.0
var trauma := 0.0
var _focus := Vector3.ZERO
var _noise := FastNoiseLite.new()
var _t := 0.0
var _intro := 0.0


func _ready() -> void:
	fov = 40.0
	near = 0.5
	far = 120.0
	_noise.frequency = 3.0
	_noise.seed = randi()


func setup(p_target: Node3D, team: int) -> void:
	target = p_target
	flip = 1.0 if team == 0 else -1.0
	_focus = target.global_position
	_intro = 1.0   # start zoomed out over the arena and swoop in
	_apply(0.0)


func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


func _process(delta: float) -> void:
	Prof.begin("camera")
	_t += delta
	if target and is_instance_valid(target):
		var desired := target.global_position + lead
		desired.x = clampf(desired.x, -BOUNDS.x, BOUNDS.x)
		desired.z = clampf(desired.z, -BOUNDS.y, BOUNDS.y)
		_focus = _focus.lerp(desired, 1.0 - exp(-delta * 7.0))
	zoom = lerpf(zoom, target_zoom, 1.0 - exp(-delta * 3.0))
	_intro = maxf(0.0, _intro - delta * 0.7)
	_apply(delta)
	Prof.end("camera")

func _apply(delta: float) -> void:
	var k := ease(_intro, 2.0)
	var z := zoom * (1.0 + k * 1.3)
	var off := OFFSET * z
	off.z *= flip
	off.x *= flip
	var focus := _focus.lerp(Vector3.ZERO, k * 0.7)
	global_position = focus + off
	look_at(focus + Vector3(0, 0.4, 0), Vector3.UP)
	# shake (squared trauma feels better: small hits are subtle, big ones punchy)
	trauma = maxf(0.0, trauma - delta * 1.6)
	var s := trauma * trauma
	h_offset = _noise.get_noise_2d(_t * 60.0, 0.0) * 0.45 * s
	v_offset = _noise.get_noise_2d(0.0, _t * 60.0) * 0.45 * s
	rotate_object_local(Vector3.FORWARD, _noise.get_noise_2d(_t * 40.0, 99.0) * 0.035 * s)


## Ray from a screen point onto the ground plane at height h (mouse aiming).
func screen_to_ground(screen_pos: Vector2, h := 0.0) -> Vector3:
	var from := project_ray_origin(screen_pos)
	var dir := project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return from
	var t := (h - from.y) / dir.y
	return from + dir * t
