class_name UplinkView
extends Node3D
## A team's scoring zone: holographic pad + twin pylons + light column. flash() plays when energy is delivered.

var team := 0
var radius := 2.5
var _rings: Array[MeshInstance3D] = []
var _column: MeshInstance3D
var _flash := 0.0
var _t := 0.0
var color := Color.WHITE


func setup(p_team: int, p_radius: float) -> void:
	team = p_team
	radius = p_radius
	color = Settings.TEAM_COLORS[team]


func _ready() -> void:
	for i in 2:
		var r := MeshInstance3D.new()
		r.mesh = Mats.quad(Vector2(radius * 2.0 + 0.4, radius * 2.0 + 0.4))
		r.material_override = Mats.ring()
		r.position.y = 0.04 + i * 0.01
		r.set_instance_shader_parameter(&"color", color)
		r.set_instance_shader_parameter(&"progress", 0.9 - i * 0.18)
		r.set_instance_shader_parameter(&"thickness", 0.035 if i == 0 else 0.02)
		r.set_instance_shader_parameter(&"fill", 0.18 if i == 0 else 0.0)
		r.set_instance_shader_parameter(&"dashes", 0.0 if i == 0 else 14.0)
		add_child(r)
		_rings.append(r)
	_column = MeshInstance3D.new()
	_column.mesh = Mats.cyl(radius * 0.92, radius * 0.92, 2.6, 24)
	_column.material_override = Mats.energy(Color(color.r, color.g, color.b, 0.25), 0.6, 0.5)
	_column.position.y = 1.3
	_column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_column)
	var back := -1.0 if team == 0 else 1.0
	for side in [-1.0, 1.0]:
		var pylon := Node3D.new()
		pylon.position = Vector3(back * 0.4, 0, side * (radius + 0.4))
		add_child(pylon)
		var base := Mats.part(Mats.box(Vector3(0.7, 0.4, 0.7)), Color("2d2b55"))
		base.position.y = 0.2
		pylon.add_child(base)
		var post := Mats.part(Mats.cyl(0.14, 0.2, 2.4, 6), Settings.TEAM_DARK[team])
		post.position.y = 1.5
		pylon.add_child(post)
		var tip := MeshInstance3D.new()
		tip.mesh = Mats.sphere(0.22, -1.0, 8, 4)
		tip.material_override = Mats.glow(color, 2.5)
		tip.position.y = 2.8
		pylon.add_child(tip)


func flash() -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 2.0)
	_rings[1].rotation.y = _t * 0.4
	var s := 1.0 + _flash * 0.12
	_rings[0].scale = Vector3(s, 1, s)
	_rings[0].set_instance_shader_parameter(&"alpha", 0.75 + sin(_t * 3.0) * 0.15 + _flash)
	_column.set_instance_shader_parameter(&"fade", 0.5 + _flash * 1.5)
