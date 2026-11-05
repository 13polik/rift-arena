class_name ProjectileView
extends Node3D
## Client-side projectile visuals. Spawned from server "ps" events and simulated locally along the same line
## (straight shots are deterministic); homing shots are steered toward the server positions from snapshots.

const POOL := 72
const STYLE := {
	# kind: [core color, glow color, core length, core radius, glow radius, trail color]
	&"bolt": [Color("e8ffff"), Color("39d8ff"), 0.7, 0.07, 0.22, Color("6ff6ff")],
	&"dart": [Color("f3e8ff"), Color("b26bff"), 0.38, 0.06, 0.2, Color("6bffd8")],
	&"overload": [Color("fffbe0"), Color("ffd23f"), 0.5, 0.32, 0.75, Color("ffe066")],
}

var _items: Array[Dictionary] = []
var _by_id := {}


func _ready() -> void:
	for i in POOL:
		var root := Node3D.new()
		root.visible = false
		add_child(root)
		var core := MeshInstance3D.new()
		core.mesh = Mats.capsule(0.5, 2.0)
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		core.rotation_degrees.x = 90.0   # capsule axis along Z (travel direction)
		root.add_child(core)
		var glow := MeshInstance3D.new()
		glow.mesh = Mats.sphere(1.0, -1.0, 12, 6)
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(glow)
		var trail: GPUParticles3D = null
		if Settings.quality >= Settings.Quality.MEDIUM:
			trail = GPUParticles3D.new()
			trail.amount = 14
			trail.lifetime = 0.2
			trail.local_coords = false
			trail.emitting = false
			trail.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 4, 8))
			var pm := ParticleProcessMaterial.new()
			pm.gravity = Vector3.ZERO
			pm.initial_velocity_min = 0.0
			pm.initial_velocity_max = 0.4
			pm.spread = 180.0
			var sc := Curve.new()
			sc.add_point(Vector2(0, 1)); sc.add_point(Vector2(1, 0))
			var ct := CurveTexture.new()
			ct.curve = sc
			pm.scale_curve = ct
			trail.process_material = pm
			var q := QuadMesh.new()
			q.size = Vector2(0.22, 0.22)
			var qm := StandardMaterial3D.new()
			qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			qm.vertex_color_use_as_albedo = true
			qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			qm.albedo_texture = VFX._soft_dot()
			q.material = qm
			trail.draw_pass_1 = q
			root.add_child(trail)
		_items.append({"root": root, "core": core, "glow": glow, "trail": trail, "active": false})


func spawn(e: Dictionary, origin_override := Vector3.INF) -> void:
	var it: Dictionary = {}
	for x in _items:
		if not x.active:
			it = x
			break
	if it.is_empty():
		return
	var st: Array = STYLE.get(StringName(e.k), STYLE[&"bolt"])
	it.active = true
	it.id = e.id
	it.dir = Vector3(e.dx, 0, e.dz).normalized()
	it.speed = e.sp
	it.range = e.r
	it.traveled = 0.0
	it.homing = e.hm
	it.server_pos = null
	it.pos = Vector3(e.x, 0, e.z)
	it.height = 0.95
	if origin_override != Vector3.INF:
		# visually start at the gun muzzle, converge onto the true path quickly
		it.offset = origin_override - Vector3(e.x, 0.95, e.z)
	else:
		it.offset = Vector3.ZERO
	var root: Node3D = it.root
	root.visible = true
	it.core.material_override = Mats.glow(st[0], 2.6)
	it.core.scale = Vector3(st[3] * 2.0, st[3] * 2.0, st[2] * 0.5)
	it.glow.material_override = Mats.energy(st[1], 1.5, 0.0)
	it.glow.scale = Vector3.ONE * st[4]
	if it.trail:
		var pm: ParticleProcessMaterial = it.trail.process_material
		pm.color = st[5]
		it.trail.restart()
		it.trail.emitting = true
	_place(it)
	_by_id[e.id] = it


func finish(id: int) -> Vector3:
	if not _by_id.has(id):
		return Vector3.INF
	var it: Dictionary = _by_id[id]
	_by_id.erase(id)
	it.active = false
	it.root.visible = false
	if it.trail:
		it.trail.emitting = false
	return it.root.global_position


## Snapshot correction for homing shots: [id, x, z, dx, dz]
func sync_homing(list: Array) -> void:
	for s in list:
		if _by_id.has(int(s[0])):
			var it: Dictionary = _by_id[int(s[0])]
			it.server_pos = Vector3(s[1], 0, s[2])
			it.dir = Vector3(s[3], 0, s[4]).normalized()


func clear() -> void:
	for id in _by_id.keys():
		finish(id)


func _place(it: Dictionary) -> void:
	var root: Node3D = it.root
	root.global_position = it.pos + Vector3(0, it.height, 0) + it.offset
	root.look_at(root.global_position + it.dir, Vector3.UP)


func _process(delta: float) -> void:
	Prof.begin("projview")
	for it in _items:
		if not it.active:
			continue
		var step: float = it.speed * delta
		it.pos += it.dir * step
		if it.server_pos != null:
			it.pos = it.pos.lerp(it.server_pos + it.dir * it.speed * 0.05, minf(1.0, delta * 10.0))
		it.offset = it.offset.lerp(Vector3.ZERO, minf(1.0, delta * 14.0))
		it.traveled += step
		# safety: hide if the server end event got lost
		if it.traveled > it.range + 3.0:
			finish(it.id)
			continue
		_place(it)
		it.glow.scale = it.glow.scale.lerp(Vector3.ONE * it.glow.scale.x * (0.92 + randf() * 0.16), 0.5)
	Prof.end("projview")
