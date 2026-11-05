class_name HeroShowcase
extends SubViewportContainer
## Big animated 3D hero for menus (HOME / CHARACTER SELECT). Own world, transparent background, idle loop,
## tap to make the hero show off (attack / ability / super / victory).

var hero_id: StringName = &"volt"
var skin := 0
var _vp: SubViewport
var _pivot: Node3D
var _visual: HeroVisual
var _cam: Camera3D
var _t := 0.0
var _showoff := [&"attack", &"ability", &"super"]
var _show_i := 0


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_2X if Settings.quality != Settings.Quality.LOW else Viewport.MSAA_DISABLED
	add_child(_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.58, 0.9)
	e.ambient_light_energy = 0.45
	e.glow_enabled = Settings.glow_enabled()
	e.glow_intensity = 0.35
	e.glow_hdr_threshold = 1.3
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -40, 0)
	key.light_energy = 0.95
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 150, 0)
	rim.light_color = Color("7fb8ff")
	rim.light_energy = 0.55
	_vp.add_child(rim)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	# glowing pedestal
	var ped := Mats.part(Mats.cyl(1.1, 1.25, 0.25, 32), Color("2a2f55"))
	ped.position.y = -0.125
	_pivot.add_child(ped)
	var ring := MeshInstance3D.new()
	ring.mesh = Mats.torus(1.08, 1.16)
	ring.material_override = Mats.glow(Color("6ff6ff"), 2.0)
	_pivot.add_child(ring)
	_cam = Camera3D.new()
	_cam.fov = 30
	_vp.add_child(_cam)
	set_hero(hero_id, skin)


func set_hero(id: StringName, p_skin := 0) -> void:
	hero_id = id
	skin = p_skin
	if _pivot == null:
		return
	if _visual:
		_visual.queue_free()
	_visual = HeroVisual.new()
	_pivot.add_child(_visual)
	_visual.setup(Skins.apply(Settings.hero_data(id), id, skin), true, true, "")
	_visual.set_facing(Vector3(0.35, 0, 1).normalized(), true)
	_visual.set_hp(1.0)
	for c in _visual.get_children():
		if c is Label3D or (c is MeshInstance3D and c.material_override is ShaderMaterial and (c.material_override as ShaderMaterial).shader == HeroVisual.HPBAR):
			c.visible = false
	var h := 2.4 * Settings.hero_data(id).model_scale
	_cam.position = Vector3(0, h * 0.62, h * 2.25)
	_cam.look_at(Vector3(0, h * 0.42, 0))
	_visual.play_action(&"respawn")


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed and _visual:
		_visual.play_action(_showoff[_show_i % _showoff.size()])
		_show_i += 1
		Audio.play(&"click")


func _process(delta: float) -> void:
	_t += delta
	if _visual:
		_visual.set_facing(Vector3(sin(_t * 0.35) * 0.6, 0, 1).normalized())
