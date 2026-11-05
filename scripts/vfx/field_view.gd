class_name FieldView
extends Node3D
## Client-side visuals for things lying on the arena floor: Rift energy shards and ability zones.

var _shards := {}        # id -> {node, t, from, to}
var _zones := {}         # id -> {node, disc, ring, particles, end}
var _shard_pool: Array[Node3D] = []
var _t := 0.0
var my_team := 0


func _ready() -> void:
	for i in 18:
		var n := Node3D.new()
		n.visible = false
		add_child(n)
		var crystal := MeshInstance3D.new()
		crystal.mesh = Mats.prism(Vector3(0.36, 0.6, 0.36))
		crystal.material_override = Mats.glow(Color("ffd84a"), 2.2)
		crystal.position.y = 0.6
		crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(crystal)
		var shell := MeshInstance3D.new()
		shell.mesh = Mats.sphere(0.42, -1.0, 10, 5)
		shell.material_override = Mats.energy(Color("ffb800"), 0.9, 0.3)
		shell.position.y = 0.6
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(shell)
		var floor_ring := MeshInstance3D.new()
		floor_ring.mesh = Mats.quad(Vector2(1.3, 1.3))
		floor_ring.material_override = Mats.ring()
		floor_ring.position.y = 0.05
		floor_ring.set_instance_shader_parameter(&"color", Color("ffcc33"))
		floor_ring.set_instance_shader_parameter(&"progress", 0.7)
		floor_ring.set_instance_shader_parameter(&"fill", 0.35)
		n.add_child(floor_ring)
		_shard_pool.append(n)


# ---------------- shards
func add_shard(id: int, pos: Vector3, from: Vector3) -> void:
	if _shards.has(id):
		return
	for n in _shard_pool:
		if not n.visible:
			n.visible = true
			n.global_position = from
			_shards[id] = {"node": n, "t": 0.0, "from": from, "to": pos}
			return


func remove_shard(id: int) -> Vector3:
	if not _shards.has(id):
		return Vector3.INF
	var s: Dictionary = _shards[id]
	s.node.visible = false
	_shards.erase(id)
	return s.to


## Full authoritative list [[id, x, z]] -> add missing, drop stale.
func sync_shards(list: Array) -> void:
	var keep := {}
	for s in list:
		keep[int(s[0])] = true
		if not _shards.has(int(s[0])):
			var p := Vector3(s[1], 0, s[2])
			add_shard(int(s[0]), p, p)
	for id in _shards.keys():
		if not keep.has(id):
			remove_shard(id)


# ---------------- zones
func add_zone(e: Dictionary) -> void:
	var heal: bool = e.e == "heal"
	var col := Color("5dff9d") if heal else (Color("7aa8ff") if e.tm == my_team else Color("c67bff"))
	var n := Node3D.new()
	n.position = Vector3(e.x, 0, e.z)
	add_child(n)
	var disc := MeshInstance3D.new()
	disc.mesh = Mats.quad(Vector2(2, 2))
	disc.material_override = Mats.ring()
	disc.scale = Vector3(e.r, 1, e.r)
	disc.position.y = 0.05
	disc.set_instance_shader_parameter(&"color", col)
	disc.set_instance_shader_parameter(&"progress", 0.97)
	disc.set_instance_shader_parameter(&"thickness", 0.035)
	disc.set_instance_shader_parameter(&"fill", 0.3)
	n.add_child(disc)
	var ring := MeshInstance3D.new()
	ring.mesh = Mats.quad(Vector2(2, 2))
	ring.material_override = Mats.ring()
	ring.scale = Vector3(e.r, 1, e.r)
	ring.position.y = 0.06
	ring.set_instance_shader_parameter(&"color", col)
	ring.set_instance_shader_parameter(&"progress", 0.8)
	ring.set_instance_shader_parameter(&"thickness", 0.02)
	ring.set_instance_shader_parameter(&"dashes", 12.0)
	n.add_child(ring)
	# a translucent dome reads clearly from the top-down camera
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = e.r
	sm.height = e.r * 0.9
	sm.is_hemisphere = true
	sm.radial_segments = 24
	sm.rings = 6
	dome.mesh = sm
	dome.material_override = Mats.energy(Color(col.r, col.g, col.b, 0.35), 0.5, 0.25)
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(dome)
	var parts := GPUParticles3D.new()
	parts.amount = int(24 * Settings.particle_scale())
	parts.lifetime = 1.2
	parts.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 5, 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = e.r * 0.95
	pm.emission_ring_inner_radius = 0.0
	pm.emission_ring_height = 0.05
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 0.6 if heal else 0.2
	pm.initial_velocity_max = 1.6 if heal else 0.6
	pm.gravity = Vector3.ZERO
	pm.color = col
	parts.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16) if heal else Vector2(0.1, 0.1)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.albedo_texture = VFX._soft_dot()
	q.material = qm
	parts.draw_pass_1 = q
	n.add_child(parts)
	n.scale = Vector3(0.2, 1, 0.2)
	create_tween().tween_property(n, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_zones[e.id] = {"node": n, "ring": ring, "dome": dome}


func remove_zone(id: int) -> void:
	if not _zones.has(id):
		return
	var z: Dictionary = _zones[id]
	_zones.erase(id)
	var tw := create_tween()
	tw.tween_property(z.node, "scale", Vector3(0.05, 1, 0.05), 0.2)
	tw.tween_callback(z.node.queue_free)


func clear() -> void:
	for id in _shards.keys():
		remove_shard(id)
	for id in _zones.keys():
		remove_zone(id)


func _process(delta: float) -> void:
	Prof.begin("field")
	_t += delta
	for id in _shards:
		var s: Dictionary = _shards[id]
		var n: Node3D = s.node
		if s.t < 1.0:   # arc out of the core
			s.t = minf(1.0, s.t + delta * 2.2)
			var p: Vector3 = s.from.lerp(s.to, s.t)
			p.y = sin(s.t * PI) * 2.0
			n.global_position = p
		else:
			n.global_position = s.to
		n.get_child(0).rotation.y = _t * 2.5 + id
		n.get_child(0).position.y = 0.6 + sin(_t * 3.0 + id) * 0.12
	for id in _zones:
		var z: Dictionary = _zones[id]
		z.ring.rotation.y = _t * 0.8
	Prof.end("field")
