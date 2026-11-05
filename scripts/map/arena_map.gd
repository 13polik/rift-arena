class_name ArenaMap
extends Node3D
## Builds "Fracture Yard" from FractureYardLayout and exposes gameplay queries (bushes, spawns, uplinks, walls).
## Collision lives under a NavigationRegion3D, so the bot navmesh is baked from the same shapes at load time.

const L = preload("res://maps/fracture_yard_layout.gd")

var solid_rects: Array[Rect2] = []   # walls + crates + core (XZ) for spawn checks
var bush_rects: Array[Rect2] = []
var bush_nodes: Array[MultiMeshInstance3D] = []
var nav_region: NavigationRegion3D
var core_view: RiftCoreView
var uplinks: Array[UplinkView] = []


func _ready() -> void:
	seed(1337) # stable decoration randomness on every client
	_build_ground()
	nav_region = NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = Props.WORLD_LAYER
	nm.agent_radius = 0.5
	nm.agent_height = 1.5
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.agent_max_climb = 0.25
	nav_region.navigation_mesh = nm
	add_child(nav_region)
	_build_collision_and_walls()
	_build_core_and_bases()
	_build_bushes()
	_build_dressing()
	nav_region.bake_navigation_mesh(false)
	randomize()


func _build_ground() -> void:
	# playable floor
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(L.HALF_W * 2.0 + 2.0, L.HALF_D * 2.0 + 2.0)
	floor_mi.mesh = pm
	var gm := ShaderMaterial.new()
	gm.shader = Mats.GROUND
	gm.set_shader_parameter("half_width", L.HALF_W)
	gm.set_shader_parameter("base_x", -L.UPLINK.x)
	floor_mi.material_override = gm
	add_child(floor_mi)
	# surrounding streets (darker asphalt with curb lines)
	var street := MeshInstance3D.new()
	var sp := PlaneMesh.new()
	sp.size = Vector2(90, 70)
	street.mesh = sp
	street.position.y = -0.4
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("1b1d33")
	sm.roughness = 1.0
	street.material_override = sm
	add_child(street)


func _build_collision_and_walls() -> void:
	# invisible ground collider (also the navmesh source surface)
	var ground := StaticBody3D.new()
	ground.collision_layer = Props.WORLD_LAYER
	var gcs := CollisionShape3D.new()
	var gbox := BoxShape3D.new()
	gbox.size = Vector3(L.HALF_W * 2.0, 1.0, L.HALF_D * 2.0)
	gcs.shape = gbox
	gcs.position.y = -0.5
	ground.add_child(gcs)
	nav_region.add_child(ground)
	# arena rim (low wall with trim) + collision
	var rim_h := 1.0
	for r in [[0.0, -L.HALF_D - 0.5, L.HALF_W * 2.0 + 2.0, 1.0], [0.0, L.HALF_D + 0.5, L.HALF_W * 2.0 + 2.0, 1.0],
			[-L.HALF_W - 0.5, 0.0, 1.0, L.HALF_D * 2.0], [L.HALF_W + 0.5, 0.0, 1.0, L.HALF_D * 2.0]]:
		nav_region.add_child(Props.wall(r[0], r[1], r[2], r[3], rim_h))
	for w in L.both(L.LEFT_WALLS):
		nav_region.add_child(Props.wall(w[0], w[1], w[2], w[3], w[4]))
		solid_rects.append(Rect2(w[0] - w[2] * 0.5, w[1] - w[3] * 0.5, w[2], w[3]))
	var crates := L.both(L.LEFT_CRATES)
	nav_region.add_child(Props.crates(crates))
	for c in crates:
		solid_rects.append(Rect2(c[0] - 0.55, c[1] - 0.55, 1.1, 1.1))
	# core collider (cylinder)
	var core_body := StaticBody3D.new()
	core_body.collision_layer = Props.WORLD_LAYER
	var ccs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = L.CORE_RADIUS
	cyl.height = 3.0
	ccs.shape = cyl
	ccs.position.y = 1.5
	core_body.add_child(ccs)
	nav_region.add_child(core_body)
	solid_rects.append(Rect2(-L.CORE_RADIUS, -L.CORE_RADIUS, L.CORE_RADIUS * 2.0, L.CORE_RADIUS * 2.0))


func _build_core_and_bases() -> void:
	core_view = RiftCoreView.new()
	add_child(core_view)
	for team in 2:
		var u := UplinkView.new()
		u.setup(team, L.UPLINK_RADIUS)
		var p := uplink_pos(team)
		u.position = p
		add_child(u)
		uplinks.append(u)
		# spawn platform behind the uplink
		var plat := Mats.part(Mats.box(Vector3(2.2, 0.12, 6.2)), Color("2a2f55"))
		plat.position = Vector3(spawn_points(team)[1].x, 0.0, 0)
		add_child(plat)
		var strip := MeshInstance3D.new()
		strip.mesh = Mats.box(Vector3(0.12, 0.14, 6.2))
		strip.material_override = Mats.glow(Settings.TEAM_COLORS[team], 2.2)
		strip.position = plat.position + Vector3(0.9 * (1 if team == 0 else -1), 0, 0)
		add_child(strip)


func _build_bushes() -> void:
	for b in L.both(L.LEFT_BUSHES):
		var mmi := Props.bush(b[0], b[1], b[2], b[3])
		add_child(mmi)
		bush_nodes.append(mmi)
		bush_rects.append(Rect2(b[0] - b[2] * 0.5, b[1] - b[3] * 0.5, b[2], b[3]))


func _build_dressing() -> void:
	var lights_left := 4 if Settings.quality == Settings.Quality.HIGH else 0
	var lamps := []
	for l in L.both(L.LEFT_LAMPS):
		var lamp := Props.lamp(l[0], l[1], lights_left > 0)
		lights_left -= 1
		add_child(lamp)
		lamps.append(lamp)
	# cables strung between lamps on the same side of the arena
	lamps.sort_custom(func(a, b): return a.position.x < b.position.x)
	for i in lamps.size():
		for j in range(i + 1, lamps.size()):
			var a: Node3D = lamps[i]
			var b: Node3D = lamps[j]
			if absf(a.position.z - b.position.z) < 0.5 and absf(a.position.x - b.position.x) < 9.0:
				add_child(Props.cable(a.get_meta(&"cable_point"), b.get_meta(&"cable_point"), 0.7))
				break
	for d in L.both(L.LEFT_DECOR):
		add_child(Props.barrel(d[0], d[1], d[2]))
	for b in L.both(L.LEFT_BUILDINGS):
		add_child(Props.building(b[0], b[1], b[2], b[3], b[4], b[5]))
	# team HQ signs behind each base + cables from rooftops into the arena
	add_child(Props.holo_sign(Vector3(-20.6, 4.0, 0), Vector2(5.0, 1.6), Settings.TEAM_COLORS[0], PI * 0.5))
	add_child(Props.holo_sign(Vector3(20.6, 4.0, 0), Vector2(5.0, 1.6), Settings.TEAM_COLORS[1], -PI * 0.5))
	add_child(Props.cable(Vector3(-15, 6.0, -12.7), Vector3(-7.5, 3.1, -11.6), 0.6))
	add_child(Props.cable(Vector3(15, 6.0, 12.7), Vector3(7.5, 3.1, 11.6), 0.6))
	add_child(Props.cable(Vector3(-7, 9.0, -12.6), Vector3(0.5, 5.0, -12.7), 1.2))
	add_child(Props.cable(Vector3(7, 9.0, 12.6), Vector3(-0.5, 5.0, 12.7), 1.2))
	# floating rift dust over the arena (cheap GPU particles)
	if Settings.quality >= Settings.Quality.MEDIUM:
		var dust := GPUParticles3D.new()
		dust.amount = 48 if Settings.quality == Settings.Quality.HIGH else 24
		dust.lifetime = 6.0
		dust.visibility_aabb = AABB(Vector3(-20, -1, -13), Vector3(40, 6, 26))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(L.HALF_W, 0.2, L.HALF_D)
		pm.direction = Vector3.UP
		pm.initial_velocity_min = 0.1
		pm.initial_velocity_max = 0.35
		pm.gravity = Vector3.ZERO
		pm.turbulence_enabled = false
		dust.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(0.07, 0.07)
		var qm := StandardMaterial3D.new()
		qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		qm.albedo_color = Color(0.6, 0.9, 1.0, 0.8)
		q.material = qm
		dust.draw_pass_1 = q
		dust.position.y = 0.3
		add_child(dust)


# ------------------------------------------------------------------ queries
func uplink_pos(team: int) -> Vector3:
	var p := L.UPLINK if team == 0 else -L.UPLINK
	return Vector3(p.x, 0, p.y)


func spawn_points(team: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for s in L.SPAWNS:
		var v: Vector2 = s if team == 0 else -s
		out.append(Vector3(v.x, 0, v.y))
	return out


func bush_index_at(p: Vector3) -> int:
	for i in bush_rects.size():
		if bush_rects[i].has_point(Vector2(p.x, p.z)):
			return i
	return -1


func is_solid(x: float, z: float) -> bool:
	if absf(x) > L.HALF_W - 0.4 or absf(z) > L.HALF_D - 0.4:
		return true
	for r in solid_rects:
		if r.grow(0.35).has_point(Vector2(x, z)):
			return true
	return false


## Visual feedback: reveal hole for the local hero + rustle when someone walks through.
func set_bush_reveal(local_pos: Vector3, local_bush: int) -> void:
	for i in bush_nodes.size():
		var m: ShaderMaterial = bush_nodes[i].material_override
		m.set_shader_parameter("reveal_pos", local_pos if i == local_bush else Vector3(1000, 0, 0))


func rustle_bush(index: int, amount: float) -> void:
	if index >= 0 and index < bush_nodes.size():
		var m: ShaderMaterial = bush_nodes[index].material_override
		m.set_shader_parameter("rustle", amount)
