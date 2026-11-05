class_name HeroVisual
extends Node3D
## Everything you SEE of a hero: model + rig, AnimationTree, team ring, nameplate & HP bar, carried energy,
## hit flash, lean, footsteps, death dissolve. Purely presentational: driven by Hero (sim) state.

signal footstep(pos: Vector3, heavy: bool)

const ALLY := Color("3d8bff")
const ENEMY := Color("ff4257")
const SELF := Color("6bff8f")
const HPBAR := preload("res://shaders/hpbar.gdshader")
const VISUAL_SCALE := 1.3   # heroes are drawn larger than their collision for mobile readability

var data: HeroData
var rig: HeroRig
var anim: HeroAnimator
var style: StringName
var hip := 0.6
var is_local := false
var is_ally := true

var _ring: MeshInstance3D
var _status_ring: MeshInstance3D
var _shadow: MeshInstance3D
var _label: Label3D
var _bar: MeshInstance3D
var _carry_root: Node3D
var _carry: Array[MeshInstance3D] = []
var _carry_label: Label3D
var _flash := 0.0
var _hp_lag := 1.0
var _hp := 1.0
var _facing := 0.0
var _target_facing := 0.0
var _lean := Vector2.ZERO
var _prev_pos := Vector3.ZERO
var _vel := Vector3.ZERO
var _step_dist := 0.0
var _t := 0.0
var _dead := false
var _dead_t := 0.0
var _tinted := false
var _super_ready := false


func setup(d: HeroData, team_is_ally: bool, local: bool, player_name: String) -> void:
	data = d
	is_local = local
	is_ally = team_is_ally
	rig = HeroRig.new()
	add_child(rig)
	var model_script: GDScript = load("res://scripts/characters/models/%s_model.gd" % d.id)
	model_script.build(rig, d)
	rig.bake()
	style = model_script.PROPS.style
	hip = model_script.PROPS.hip
	rig.scale = Vector3.ONE * d.model_scale * VISUAL_SCALE
	anim = HeroAnimator.new()
	anim.setup(self, AnimLibrary.build(style, hip))
	_build_ground_decals()
	_build_nameplate(player_name)
	_build_carry()
	_prev_pos = global_position if is_inside_tree() else Vector3.ZERO


func _team_color() -> Color:
	return SELF if is_local else (ALLY if is_ally else ENEMY)


func _build_ground_decals() -> void:
	_shadow = MeshInstance3D.new()
	_shadow.mesh = Mats.quad(Vector2(1.9, 1.9) * data.model_scale)
	_shadow.material_override = _shadow_mat()
	_shadow.position.y = 0.02
	add_child(_shadow)
	_ring = MeshInstance3D.new()
	_ring.mesh = Mats.quad(Vector2(2.0, 2.0) * data.model_scale)
	_ring.material_override = Mats.ring()
	_ring.position.y = 0.035
	_ring.set_instance_shader_parameter(&"color", _team_color())
	_ring.set_instance_shader_parameter(&"progress", 0.8)
	_ring.set_instance_shader_parameter(&"thickness", 0.09 if is_local else 0.07)
	_ring.set_instance_shader_parameter(&"fill", 0.12)
	add_child(_ring)
	_status_ring = MeshInstance3D.new()
	_status_ring.mesh = Mats.quad(Vector2(2.0, 2.0) * data.model_scale)
	_status_ring.material_override = Mats.ring()
	_status_ring.position.y = 0.04
	_status_ring.visible = false
	_status_ring.set_instance_shader_parameter(&"dashes", 6.0)
	add_child(_status_ring)


static var _shadow_material: ShaderMaterial
static func _shadow_mat() -> ShaderMaterial:
	if _shadow_material == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled;
void fragment(){ float d = length(UV * 2.0 - 1.0); ALBEDO = vec3(0.02, 0.0, 0.08); ALPHA = smoothstep(1.0, 0.2, d) * 0.45; }"""
		_shadow_material = ShaderMaterial.new()
		_shadow_material.shader = sh
	return _shadow_material


func _build_nameplate(player_name: String) -> void:
	var top := 2.25 * data.model_scale * VISUAL_SCALE
	_label = Label3D.new()
	_label.text = player_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = false
	_label.pixel_size = 0.0045
	_label.font_size = 44
	_label.outline_size = 12
	_label.modulate = Color.WHITE if is_local else _team_color().lightened(0.35)
	_label.outline_modulate = Color(0.03, 0.03, 0.1)
	_label.position.y = top + 0.32
	_label.render_priority = 20
	_label.outline_render_priority = 19
	add_child(_label)
	_bar = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.15, 0.17)
	_bar.mesh = q
	var m := ShaderMaterial.new()
	m.shader = HPBAR
	m.render_priority = 18
	_bar.material_override = m
	_bar.position.y = top
	_bar.set_instance_shader_parameter(&"fill_color", _team_color())
	_bar.set_instance_shader_parameter(&"segments", data.max_hp / 400.0)
	_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bar)


func _build_carry() -> void:
	_carry_root = Node3D.new()
	_carry_root.position.y = 2.3 * data.model_scale
	add_child(_carry_root)
	for i in 8:
		var s := MeshInstance3D.new()
		s.mesh = Mats.prism(Vector3(0.16, 0.3, 0.16))
		s.material_override = Mats.glow(Color("ffd84a"), 2.4)
		s.visible = false
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_carry_root.add_child(s)
		_carry.append(s)
	_carry_label = Label3D.new()
	_carry_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_carry_label.no_depth_test = true
	_carry_label.pixel_size = 0.005
	_carry_label.font_size = 40
	_carry_label.outline_size = 12
	_carry_label.modulate = Color("ffe066")
	_carry_label.outline_modulate = Color(0.15, 0.08, 0.0)
	_carry_label.position = Vector3(0.75, 0.75, 0)
	_carry_label.render_priority = 20
	_carry_label.visible = false
	add_child(_carry_label)


# ------------------------------------------------------------------ API used by Hero
func set_facing(dir: Vector3, instant := false) -> void:
	if dir.length_squared() < 0.0001:
		return
	_target_facing = atan2(-dir.x, -dir.z)
	if instant:
		_facing = _target_facing
		rig.rotation.y = _facing


func set_hp(frac: float) -> void:
	frac = clampf(frac, 0.0, 1.0)
	if is_equal_approx(frac, _hp):
		return
	if frac > _hp:
		_hp_lag = frac
	_hp = frac
	_bar.set_instance_shader_parameter(&"hp", frac)


var _last_carry := -1
func set_carried(n: int, glowing: bool) -> void:
	if n == _last_carry:
		return
	_last_carry = n
	for i in _carry.size():
		_carry[i].visible = i < n
	_carry_label.visible = n > 0
	_carry_label.text = "%d" % n
	_ring.set_instance_shader_parameter(&"fill", 0.35 if glowing else 0.12)


func set_super_ready(on: bool) -> void:
	_super_ready = on


var _last_status := -1
func set_status(slowed: bool, protected: bool) -> void:
	var key := int(slowed) + int(protected) * 2
	if key == _last_status:
		return
	_last_status = key
	_status_ring.visible = slowed
	if slowed:
		_status_ring.set_instance_shader_parameter(&"color", Color("b46bff"))
	_bar.set_instance_shader_parameter(&"shield", 1.0 if protected else 0.0)


## Allies hiding in grass get a shaded tint so you can still read them.
func set_in_bush(on: bool) -> void:
	if on == _tinted:
		return
	_tinted = on
	for m in rig.meshes:
		m.set_instance_shader_parameter(&"tint_amount", 0.45 if on else 0.0)
		m.set_instance_shader_parameter(&"tint", Color("1d6b55"))


func play_action(slot: StringName) -> void:
	anim.play_action(slot)


func hit(strength: float) -> void:
	_flash = 1.0
	if strength > 0.3:
		anim.play_hit()


func die() -> void:
	_dead = true
	_dead_t = 0.0
	anim.set_state("dead")
	_bar.visible = false
	_label.visible = false
	_ring.visible = false
	_status_ring.visible = false
	set_carried(0, false)


func respawn() -> void:
	_dead = false
	rig.scale = Vector3.ONE * data.model_scale * VISUAL_SCALE
	rig.position = Vector3.ZERO
	visible = true
	_bar.visible = true
	_label.visible = true
	_ring.visible = true
	anim.set_state("alive")
	anim.play_action(&"respawn")
	_flash = 1.0
	_hp_lag = 1.0


func set_end_state(won: bool) -> void:
	if not _dead:
		anim.set_state("victory" if won else "defeat")


func muzzle_position() -> Vector3:
	if rig.joints.has("Muzzle"):
		return rig.j("Muzzle").global_position
	return global_position + Vector3(0, 1.0, 0)


# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	Prof.begin("herovis")
	_t += delta
	var pos := global_position
	var v := (pos - _prev_pos) / maxf(delta, 0.0001)
	_prev_pos = pos
	if v.length() > 20.0:   # teleport (blink / respawn): don't treat as movement
		v = Vector3.ZERO
	_vel = _vel.lerp(v, minf(1.0, delta * 12.0))
	var speed := Vector2(_vel.x, _vel.z).length()

	# turning
	_facing = lerp_angle(_facing, _target_facing, minf(1.0, delta * 16.0))
	rig.rotation.y = _facing

	if _dead:
		_dead_t += delta
		if _dead_t > 1.1:   # dissolve away after the death animation
			var k := clampf((_dead_t - 1.1) / 0.5, 0.0, 1.0)
			rig.scale = Vector3.ONE * data.model_scale * VISUAL_SCALE * (1.0 - k * 0.9)
			rig.position.y = -k * 0.4
			if k >= 1.0:
				visible = false
		Prof.end("herovis")
		return

	# locomotion blend + playback rate matched to ground speed
	var walk_speed := 2.6
	var run_speed := data.move_speed
	var blend := 0.0
	var rate := 1.0
	if speed > 0.3:
		blend = clampf(0.5 + 0.5 * (speed - walk_speed) / maxf(0.1, run_speed - walk_speed), 0.3, 1.0)
		rate = clampf(speed / (run_speed if blend > 0.75 else walk_speed), 0.7, 1.4)
	anim.set_locomotion(blend, rate)

	# lean into movement (in model space)
	var local_v := Vector3(_vel.x, 0, _vel.z).rotated(Vector3.UP, -_facing)
	_lean = _lean.lerp(Vector2(local_v.z, -local_v.x) * 0.025, minf(1.0, delta * 8.0))
	rig.rotation.x = clampf(_lean.x, -0.22, 0.22)
	rig.rotation.z = clampf(_lean.y, -0.18, 0.18)

	# footsteps (dust + sound handled by listeners)
	_step_dist += speed * delta
	var stride := 1.25 * data.model_scale
	if _step_dist > stride:
		_step_dist = 0.0
		footstep.emit(pos, data.sfx_footstep == &"step_heavy")

	# hit flash decay
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 6.0)
		for m in rig.meshes:
			m.set_instance_shader_parameter(&"flash", _flash)
	# HP lag chunk shrinks after a short delay
	if _hp_lag > _hp:
		_hp_lag = maxf(_hp, _hp_lag - delta * 0.6)
		_bar.set_instance_shader_parameter(&"lag", _hp_lag)
	# carried shards orbit the head
	var n := 0
	for s in _carry:
		if s.visible:
			n += 1
	if n > 0:
		for i in _carry.size():
			if not _carry[i].visible:
				continue
			var a := _t * 2.2 + TAU * i / n
			_carry[i].position = Vector3(cos(a) * 0.55, sin(_t * 3.0 + i) * 0.08, sin(a) * 0.55)
			_carry[i].rotation.y = -a
	# super-ready pulse on the ring
	if _super_ready and is_local:
		_ring.set_instance_shader_parameter(&"color", Color("ffd23f").lerp(SELF, 0.5 + 0.5 * sin(_t * 6.0)))
	elif is_local:
		_ring.set_instance_shader_parameter(&"color", SELF)
	# model-specific idle motion (drones, coils ...)
	if rig.face.has("tick"):
		rig.face["tick"].call(delta, _t, speed)
	Prof.end("herovis")
