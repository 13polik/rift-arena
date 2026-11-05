class_name VFX
extends Node3D
## Pooled visual effects: GPU particle bursts, expanding ground rings / cracks, light flashes, damage numbers.
## Nothing is instantiated during combat; every effect reuses a pre-built node. Counts scale with quality.

var camera: GameCamera
var _pools := {}          # kind -> Array[GPUParticles3D]
var _cursor := {}
var _rings: Array = []    # [{mi, t, dur, r0, r1, delay, color, fill, cracks, thick}]
var _lights: Array = []   # [{light, t, dur, energy}]
var _numbers: Array = []  # [{label, t, vel}]
var _pscale := 1.0

const KINDS := {
	# kind: [amount, lifetime, vel_min, vel_max, spread, gravity_y, size, additive, explosiveness, damping]
	&"spark":  [16, 0.35, 4.0, 9.0, 75.0, -14.0, 0.075, true, 1.0, 2.0],
	&"impact": [10, 0.25, 2.0, 5.0, 90.0, -6.0, 0.07, true, 1.0, 3.0],
	&"energy": [44, 0.7, 3.0, 10.0, 180.0, 0.0, 0.16, true, 1.0, 9.0],
	&"smoke":  [14, 1.1, 0.4, 2.0, 180.0, 0.6, 0.55, false, 0.9, 1.5],
	&"dust":   [18, 0.6, 1.5, 4.5, 85.0, -1.0, 0.3, false, 1.0, 5.0],
	&"debris": [16, 0.85, 3.0, 7.0, 40.0, -16.0, 0.12, false, 1.0, 0.5],
	&"heal":   [10, 1.0, 0.6, 1.6, 30.0, 1.2, 0.12, true, 0.3, 0.5],
	&"pickup": [14, 0.45, 2.0, 5.0, 180.0, -3.0, 0.09, true, 1.0, 3.0],
	&"death":  [30, 0.9, 2.5, 7.0, 90.0, -9.0, 0.11, true, 1.0, 1.0],
	&"spawn":  [24, 0.9, 1.5, 4.5, 12.0, 0.0, 0.1, true, 0.6, 1.0],
	&"muzzle": [8, 0.12, 2.0, 5.0, 25.0, 0.0, 0.08, true, 1.0, 6.0],
	&"step":   [5, 0.4, 0.4, 1.2, 70.0, 0.0, 0.18, false, 1.0, 3.0],
}


func _ready() -> void:
	_pscale = Settings.particle_scale()
	for kind in KINDS:
		var arr: Array[GPUParticles3D] = []
		var n := 6 if kind in [&"spark", &"impact", &"step", &"muzzle", &"dust"] else 4
		for i in n:
			arr.append(_make_emitter(kind))
		_pools[kind] = arr
		_cursor[kind] = 0
	for i in 18:
		var mi := MeshInstance3D.new()
		mi.mesh = Mats.quad(Vector2(2, 2))
		mi.material_override = Mats.ring()
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_rings.append({"mi": mi, "t": 1.0, "dur": 1.0})
	if Settings.quality >= Settings.Quality.MEDIUM:
		for i in 3:
			var l := OmniLight3D.new()
			l.visible = false
			l.shadow_enabled = false
			add_child(l)
			_lights.append({"light": l, "t": 1.0, "dur": 1.0, "energy": 0.0})
	for i in 24:
		var lb := Label3D.new()
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.no_depth_test = true
		lb.pixel_size = 0.006
		lb.font_size = 64
		lb.outline_size = 16
		lb.render_priority = 30
		lb.outline_render_priority = 29
		lb.visible = false
		add_child(lb)
		_numbers.append({"label": lb, "t": 1.0, "vel": Vector3.ZERO})


func _make_emitter(kind: StringName) -> GPUParticles3D:
	var c: Array = KINDS[kind]
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(2, int(c[0] * _pscale))
	p.lifetime = c[1]
	p.explosiveness = c[8]
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-6, -2, -6), Vector3(12, 8, 12))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = c[4]
	pm.initial_velocity_min = c[2]
	pm.initial_velocity_max = c[3]
	pm.gravity = Vector3(0, c[5], 0)
	pm.damping_min = c[9]
	pm.damping_max = c[9]
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	var sc := Curve.new()
	if kind == &"smoke" or kind == &"step" or kind == &"dust":
		sc.add_point(Vector2(0, 0.5)); sc.add_point(Vector2(1, 1.6))
	else:
		sc.add_point(Vector2(0, 1.0)); sc.add_point(Vector2(1, 0.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	if kind == &"spawn":
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_radius = 0.8
		pm.emission_ring_inner_radius = 0.6
		pm.emission_ring_height = 0.05
	elif kind == &"dust" or kind == &"step":
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.3
	p.process_material = pm
	if kind == &"debris":
		var bm := BoxMesh.new()
		bm.size = Vector3(1, 1, 1) * c[6] * 1.6
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = Color("6a5a7a")
		bm.material = mat
		p.draw_pass_1 = bm
	else:
		var q := QuadMesh.new()
		q.size = Vector2(c[6], c[6]) * 2.0
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if c[7]:
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_texture = _soft_dot()
		q.material = mat
		p.draw_pass_1 = q
	add_child(p)
	return p


static var _dot_tex: Texture2D
static func _soft_dot() -> Texture2D:
	if _dot_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.85))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 32
		gt.height = 32
		_dot_tex = gt
	return _dot_tex


## Fire a particle burst. dir tilts the emission (e.g. sparks fly away from the hit direction).
func burst(kind: StringName, pos: Vector3, color := Color.WHITE, scale := 1.0, dir := Vector3.UP) -> void:
	if not _pools.has(kind):
		return
	var arr: Array = _pools[kind]
	var i: int = _cursor[kind]
	_cursor[kind] = (i + 1) % arr.size()
	var p: GPUParticles3D = arr[i]
	var pm: ParticleProcessMaterial = p.process_material
	pm.color = color
	pm.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	p.scale = Vector3.ONE * scale
	p.global_position = pos
	p.restart()
	p.emitting = true


## Expanding ground ring (shockwaves, pulses, landings). cracks > 0 draws ground fractures.
func ring(pos: Vector3, r0: float, r1: float, color: Color, dur := 0.45, delay := 0.0, thick := 0.08, fill := 0.0, cracks := 0.0) -> void:
	var slot: Dictionary = _rings[0]
	for r in _rings:
		if r.t >= r.dur and not r.mi.visible:
			slot = r
			break
	slot.mi.global_position = Vector3(pos.x, 0.06, pos.z)
	slot.t = 0.0
	slot.dur = dur
	slot.r0 = r0
	slot.r1 = r1
	slot.delay = delay
	slot.mi.visible = delay <= 0.0
	slot.mi.set_instance_shader_parameter(&"color", color)
	slot.mi.set_instance_shader_parameter(&"thickness", thick)
	slot.mi.set_instance_shader_parameter(&"fill", fill)
	slot.mi.set_instance_shader_parameter(&"cracks", cracks)
	slot.mi.set_instance_shader_parameter(&"dashes", 0.0)
	slot.mi.set_instance_shader_parameter(&"arc", 6.3)
	_apply_ring(slot, 0.0)


## A cone-shaped swing arc (melee), oriented by dir.
func arc(pos: Vector3, dir: Vector3, radius: float, arc_deg: float, color: Color) -> void:
	ring(pos, radius * 0.95, radius, color, 0.22, 0.0, 0.5, 0.55)
	for r in _rings:
		if r.t == 0.0 and r.mi.global_position.is_equal_approx(Vector3(pos.x, 0.06, pos.z)):
			r.mi.set_instance_shader_parameter(&"arc", deg_to_rad(arc_deg))
			r.mi.rotation.y = atan2(-dir.z, dir.x)
			break


func _apply_ring(r: Dictionary, k: float) -> void:
	var rad: float = lerpf(r.r0, r.r1, ease(k, 0.4))
	r.mi.scale = Vector3(rad, 1, rad)
	r.mi.set_instance_shader_parameter(&"progress", 0.92)
	r.mi.set_instance_shader_parameter(&"alpha", 1.0 - k * k)


func flash(pos: Vector3, color: Color, energy := 4.0, rng := 6.0, dur := 0.25) -> void:
	if _lights.is_empty():
		return
	var slot: Dictionary = _lights[0]
	for l in _lights:
		if l.t >= l.dur:
			slot = l
			break
	slot.t = 0.0
	slot.dur = dur
	slot.energy = energy
	var light: OmniLight3D = slot.light
	light.global_position = pos + Vector3(0, 1.2, 0)
	light.light_color = color
	light.omni_range = rng
	light.light_energy = energy
	light.visible = true


func number(pos: Vector3, text: String, color: Color, big := false) -> void:
	var slot: Dictionary = _numbers[0]
	var oldest := -1.0
	for n in _numbers:
		if n.t >= 1.0:
			slot = n
			break
		if n.t > oldest:
			oldest = n.t
			slot = n
	var lb: Label3D = slot.label
	lb.text = text
	lb.modulate = color
	lb.outline_modulate = Color(0.08, 0.02, 0.12)
	lb.font_size = 84 if big else 60
	lb.global_position = pos + Vector3(randf_range(-0.3, 0.3), 2.3, randf_range(-0.2, 0.2))
	lb.visible = true
	slot.t = 0.0
	slot.vel = Vector3(randf_range(-0.6, 0.6), 2.6, 0)


func shake(amount: float) -> void:
	if camera:
		camera.add_trauma(amount)


func _process(delta: float) -> void:
	Prof.begin("vfx")
	for r in _rings:
		if r.t >= r.dur:
			continue
		if r.delay > 0.0:
			r.delay -= delta
			if r.delay <= 0.0:
				r.mi.visible = true
			continue
		r.t += delta
		var k := clampf(r.t / r.dur, 0.0, 1.0)
		_apply_ring(r, k)
		if k >= 1.0:
			r.mi.visible = false
	for l in _lights:
		if l.t >= l.dur:
			continue
		l.t += delta
		var k2 := clampf(l.t / l.dur, 0.0, 1.0)
		l.light.light_energy = l.energy * (1.0 - k2)
		if k2 >= 1.0:
			l.light.visible = false
	for n in _numbers:
		if n.t >= 1.0:
			continue
		n.t += delta / 0.85
		var lb: Label3D = n.label
		lb.global_position += n.vel * delta
		n.vel.y -= 5.0 * delta
		var pop := 1.0 + maxf(0.0, 0.35 - n.t) * 2.0
		lb.scale = Vector3.ONE * pop
		lb.modulate.a = clampf((1.0 - n.t) * 3.0, 0.0, 1.0)
		lb.outline_modulate.a = lb.modulate.a
		if n.t >= 1.0:
			lb.visible = false
	Prof.end("vfx")
