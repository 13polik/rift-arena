class_name RiftCoreView
extends Node3D
## The animated Rift Core in the middle of the map: floating crystal, orbiting rings, energy beam, particles.
## pulse() is triggered by the mode whenever the core releases energy shards.

var crystal: Node3D
var rings: Array[MeshInstance3D] = []
var light: OmniLight3D
var shards: Array[MeshInstance3D] = []
var _pulse := 0.0
var _t := 0.0
var _wave: MeshInstance3D


func _ready() -> void:
	# pedestal (stacked, chunky)
	var p1 := Mats.part(Mats.cyl(1.35, 1.6, 0.35, 8), Color("2d2b55"))
	p1.position.y = 0.17
	add_child(p1)
	var p2 := Mats.part(Mats.cyl(1.05, 1.25, 0.35, 8), Color("4b437f"), Color(0.3, 0.9, 1.0, 0.15))
	p2.position.y = 0.52
	add_child(p2)
	for i in 4:
		var claw := Mats.part(Mats.prism(Vector3(0.35, 1.5, 0.35)), Color("6c5fc7"))
		var a := TAU * i / 4.0 + PI / 4.0
		var dir := Vector3(cos(a), 0, sin(a))
		claw.position = dir * 1.2 + Vector3(0, 1.2, 0)
		# tilt the top of each claw inward so they cradle the crystal
		claw.basis = Basis(dir.cross(Vector3.UP).normalized(), 0.4)
		add_child(claw)
	# crystal: faceted gem with an energy shell
	crystal = Node3D.new()
	crystal.position.y = 2.5
	add_child(crystal)
	var gem := SphereMesh.new()
	gem.radius = 0.62
	gem.height = 1.9
	gem.radial_segments = 6
	gem.rings = 2
	var core := Mats.part(gem, Color("7ff6ff"), Color(0.3, 0.95, 1.0, 1.3))
	crystal.add_child(core)
	var shell := MeshInstance3D.new()
	var gem2 := gem.duplicate()
	gem2.radius = 0.8
	gem2.height = 2.4
	shell.mesh = gem2
	shell.material_override = Mats.energy(Color("4ff2ff"), 1.2)
	crystal.add_child(shell)
	# orbiting rings
	for i in 2:
		var r := MeshInstance3D.new()
		r.mesh = Mats.torus(1.15 + i * 0.35, 1.25 + i * 0.35)
		r.material_override = Mats.glow(Color("6bf3ff") if i == 0 else Color("b48cff"), 1.6)
		r.position.y = 2.5
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(r)
		rings.append(r)
	# small floating fragments
	for i in 5:
		var s := Mats.part(Mats.prism(Vector3(0.18, 0.35, 0.18)), Color("a7f8ff"), Color(0.4, 0.95, 1.0, 0.8))
		add_child(s)
		shards.append(s)
	# beam into the sky
	var beam := MeshInstance3D.new()
	beam.mesh = Mats.cyl(0.25, 0.4, 7.0, 10)
	beam.material_override = Mats.energy(Color(0.35, 0.9, 1.0, 0.35), 0.8, 0.6)
	beam.position.y = 6.0
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	# expanding pulse wave (ground)
	_wave = MeshInstance3D.new()
	_wave.mesh = Mats.quad(Vector2(2, 2))
	_wave.material_override = Mats.ring()
	_wave.position.y = 0.06
	_wave.set_instance_shader_parameter(&"color", Color(0.4, 0.95, 1.0, 1.0))
	_wave.set_instance_shader_parameter(&"alpha", 0.0)
	add_child(_wave)
	# rising motes
	var motes := GPUParticles3D.new()
	motes.amount = 24
	motes.lifetime = 2.2
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 1.2
	pm.emission_ring_inner_radius = 0.6
	pm.emission_ring_height = 0.1
	pm.direction = Vector3.UP
	pm.spread = 10.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	motes.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.albedo_color = Color(0.5, 1.0, 1.0)
	q.material = qm
	motes.draw_pass_1 = q
	motes.position.y = 0.8
	add_child(motes)
	if Settings.quality >= Settings.Quality.MEDIUM:
		light = OmniLight3D.new()
		light.light_color = Color("5ff0ff")
		light.light_energy = 2.0
		light.omni_range = 7.0
		light.position.y = 2.4
		add_child(light)


func pulse() -> void:
	_pulse = 1.0


func _process(delta: float) -> void:
	Prof.begin("core")
	_t += delta
	_pulse = maxf(0.0, _pulse - delta * 1.2)
	crystal.rotation.y += delta * (1.0 + _pulse * 6.0)
	crystal.position.y = 2.5 + sin(_t * 1.8) * 0.15
	var s := 1.0 + _pulse * 0.35
	crystal.scale = Vector3(s, s, s)
	rings[0].rotation = Vector3(sin(_t * 0.7) * 0.5, _t * 1.4, cos(_t * 0.9) * 0.4)
	rings[1].rotation = Vector3(cos(_t * 0.6) * 0.6, -_t * 1.1, sin(_t * 0.8) * 0.5)
	for i in shards.size():
		var a := _t * 0.9 + TAU * i / shards.size()
		shards[i].position = Vector3(cos(a) * 1.7, 2.3 + sin(_t * 2.0 + i) * 0.35, sin(a) * 1.7)
		shards[i].rotation.y = -a
	if light:
		light.light_energy = 2.0 + _pulse * 5.0 + sin(_t * 4.0) * 0.3
	# wave grows while the pulse decays
	var w := 1.0 - _pulse
	_wave.scale = Vector3.ONE * (1.5 + w * 4.5)
	_wave.set_instance_shader_parameter(&"progress", 0.9)
	_wave.set_instance_shader_parameter(&"alpha", _pulse)
	Prof.end("core")
