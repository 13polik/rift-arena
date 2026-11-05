class_name Props
extends RefCounted
## Factory for environment props. Each function returns a ready Node3D; collisions use simple box shapes.

const WORLD_LAYER := 1

static func _static_box(size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position.y = size.y * 0.5
	body.add_child(cs)
	return body


static func wall_material() -> ShaderMaterial:
	return Mats.panel("wall", {
		"base_color": Color("343a72"), "edge_color": Color("6d78d6"), "trim_color": Color("4ff2ff"),
		"trim_strength": 1.6, "panel_size": 1.2, "stripes": 1.0})


static func wall(x: float, z: float, w: float, d: float, h: float) -> StaticBody3D:
	var body := _static_box(Vector3(w, h, d))
	body.position = Vector3(x, 0, z)
	var mi := MeshInstance3D.new()
	mi.mesh = Mats.box(Vector3(1, 1, 1))
	mi.material_override = wall_material()
	mi.scale = Vector3(w, h, d)
	mi.position.y = h * 0.5
	body.add_child(mi)
	# top cap (lighter, slightly wider) for a chunky silhouette from above
	var cap := MeshInstance3D.new()
	cap.mesh = Mats.box(Vector3(1, 1, 1))
	cap.material_override = Mats.panel("wallcap", {"base_color": Color("5560b8"), "edge_color": Color("9aa6ff"), "trim_strength": 0.0, "panel_size": 0.8})
	cap.scale = Vector3(w + 0.14, 0.16, d + 0.14)
	cap.position.y = h + 0.02
	body.add_child(cap)
	return body


## All crates of one style in a single MultiMesh (1 draw call) + one static body with many shapes.
static func crates(list: Array) -> Node3D:
	var root := Node3D.new()
	var styles := [
		{"base_color": Color("e8892a"), "edge_color": Color("7a3a12"), "trim_color": Color("fff07a"), "trim_strength": 0.0, "panel_size": 0.55, "edge_width": 0.1},
		{"base_color": Color("1f8f8a"), "edge_color": Color("0c3f45"), "trim_color": Color("6bfff0"), "trim_strength": 0.9, "panel_size": 0.55, "edge_width": 0.1},
	]
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	root.add_child(body)
	for style in 2:
		var items := list.filter(func(c): return c[2] == style)
		if items.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Mats.box(Vector3(1.1, 1.1, 1.1))
		mm.instance_count = items.size()
		for i in items.size():
			var c: Array = items[i]
			var t := Transform3D(Basis(Vector3.UP, deg_to_rad(randf_range(-6, 6))), Vector3(c[0], 0.55, c[1]))
			mm.set_instance_transform(i, t)
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = Vector3(1.1, 1.1, 1.1)
			cs.shape = sh
			cs.position = Vector3(c[0], 0.55, c[1])
			body.add_child(cs)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = Mats.panel("crate%d" % style, styles[style])
		root.add_child(mmi)
	return root


## A patch of rift-grass made of leaf clusters (MultiMesh). Own material so it can rustle / reveal locally.
static func bush(x: float, z: float, w: float, d: float) -> MultiMeshInstance3D:
	var pts := []
	var step := 0.62
	var nx := maxi(1, int(w / step))
	var nz := maxi(1, int(d / step))
	for ix in nx:
		for iz in nz:
			var px := x - w * 0.5 + (ix + 0.5) * w / nx + randf_range(-0.12, 0.12)
			var pz := z - d * 0.5 + (iz + 0.5) * d / nz + randf_range(-0.12, 0.12)
			pts.append(Vector3(px, 0, pz))
	# each point gets a few tall leaf blades (tapered cylinders) leaning outward -> reads as rift grass from above
	var blade := CylinderMesh.new()
	blade.top_radius = 0.0
	blade.bottom_radius = 0.3
	blade.height = 1.45
	blade.radial_segments = 5
	blade.rings = 2
	var per := 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = blade
	mm.instance_count = pts.size() * per
	for i in pts.size():
		for k in per:
			var s := randf_range(0.8, 1.15)
			var lean := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
			var b := Basis(lean.cross(Vector3.UP).normalized() if lean.length() > 0.1 else Vector3.RIGHT, randf_range(0.15, 0.4))
			b = b * Basis(Vector3.UP, randf() * TAU)
			b = b.scaled(Vector3(s, s * randf_range(0.85, 1.2), s))
			var off := Vector3(randf_range(-0.18, 0.18), 0, randf_range(-0.18, 0.18))
			mm.set_instance_transform(i * per + k, Transform3D(b, pts[i] + off + Vector3(0, 0.62 * s, 0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = Mats.FOLIAGE
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


static func lamp(x: float, z: float, with_light: bool) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(x, 0, z)
	var pole := Mats.part(Mats.cyl(0.08, 0.12, 3.4, 8), Color("2c2e48"))
	pole.position.y = 1.7
	root.add_child(pole)
	var base := Mats.part(Mats.cyl(0.25, 0.3, 0.3, 8), Color("3b3f66"))
	base.position.y = 0.15
	root.add_child(base)
	var arm := Mats.part(Mats.box(Vector3(1.0, 0.1, 0.12)), Color("2c2e48"))
	var inward := -signf(z) if absf(z) > 10.0 else -signf(x)
	var dir := Vector3(0, 0, inward) if absf(z) > 10.0 else Vector3(inward, 0, 0)
	arm.position = Vector3(0, 3.35, 0) + dir * 0.45
	arm.rotation.y = PI * 0.5 if absf(z) > 10.0 else 0.0
	root.add_child(arm)
	var head := Mats.part(Mats.box(Vector3(0.45, 0.18, 0.3)), Color("1f2138"))
	head.position = Vector3(0, 3.3, 0) + dir * 0.9
	root.add_child(head)
	var bulb := MeshInstance3D.new()
	bulb.mesh = Mats.box(Vector3(0.36, 0.05, 0.22))
	bulb.material_override = Mats.glow(Color("fff2c4"), 3.0)
	bulb.position = head.position - Vector3(0, 0.1, 0)
	root.add_child(bulb)
	if with_light:
		var l := OmniLight3D.new()
		l.light_color = Color("ffd9a0")
		l.light_energy = 1.6
		l.omni_range = 6.5
		l.position = bulb.position - Vector3(0, 0.3, 0)
		root.add_child(l)
	root.set_meta(&"cable_point", Vector3(x, 3.1, z))
	return root


## Sagging power cable between two points (generated tube).
static func cable(a: Vector3, b: Vector3, sag := 0.8, r := 0.035) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 12
	var sides := 5
	var pts: Array[Vector3] = []
	for i in segs + 1:
		var t := float(i) / segs
		var p := a.lerp(b, t)
		p.y -= sag * 4.0 * t * (1.0 - t)
		pts.append(p)
	for i in segs:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var dir := (p1 - p0).normalized()
		var side := dir.cross(Vector3.UP).normalized()
		if side.length() < 0.1:
			side = Vector3.RIGHT
		var up := side.cross(dir).normalized()
		for s in sides:
			var a0 := TAU * s / sides
			var a1 := TAU * (s + 1) / sides
			var o0 := (side * cos(a0) + up * sin(a0)) * r
			var o1 := (side * cos(a1) + up * sin(a1)) * r
			for v in [p0 + o0, p1 + o0, p1 + o1, p0 + o0, p1 + o1, p0 + o1]:
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("15162a")
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func barrel(x: float, z: float, kind: int) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(x, 0, z)
	if kind == 0:
		var b := Mats.part(Mats.cyl(0.32, 0.32, 0.9, 12), Color("d8443d"))
		b.position.y = 0.45
		root.add_child(b)
		var band := Mats.part(Mats.cyl(0.335, 0.335, 0.1, 12), Color("ffd23f"))
		band.position.y = 0.6
		root.add_child(band)
	else:
		# rift capacitor: little glowing canister
		var b := Mats.part(Mats.cyl(0.26, 0.3, 0.7, 10), Color("3b3f66"))
		b.position.y = 0.35
		root.add_child(b)
		var g := MeshInstance3D.new()
		g.mesh = Mats.cyl(0.18, 0.18, 0.45, 10)
		g.material_override = Mats.energy(Color("4ff2ff"), 1.8)
		g.position.y = 0.95
		root.add_child(g)
	return root


static func building(x: float, z: float, w: float, d: float, h: float, style: int) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(x, 0, z)
	var palettes := [
		{"base_color": Color("37406e"), "edge_color": Color("5c6aa8"), "trim_color": Color("ff6bd5"), "trim_strength": 1.2, "panel_size": 2.0, "windows": 1.0},
		{"base_color": Color("2f5a6e"), "edge_color": Color("5fa3b8"), "trim_color": Color("4ff2ff"), "trim_strength": 1.2, "panel_size": 2.0, "windows": 1.0, "window_color": Color("8ff5ff")},
		{"base_color": Color("5a3e6e"), "edge_color": Color("9b72b8"), "trim_color": Color("ffd23f"), "trim_strength": 1.4, "panel_size": 2.0, "windows": 1.0},
	]
	var mi := MeshInstance3D.new()
	mi.mesh = Mats.box(Vector3(1, 1, 1))
	mi.material_override = Mats.panel("bld%d" % style, palettes[style])
	mi.scale = Vector3(w, h, d)
	mi.position.y = h * 0.5
	root.add_child(mi)
	var roof := Mats.part(Mats.box(Vector3(w + 0.3, 0.3, d + 0.3)), Color("232845"))
	roof.position.y = h + 0.15
	root.add_child(roof)
	# rooftop clutter: AC units, antenna, beacon
	var ac := Mats.part(Mats.box(Vector3(1.2, 0.7, 1.0)), Color("8a93b8"))
	ac.position = Vector3(-w * 0.25, h + 0.65, 0)
	root.add_child(ac)
	var ant := Mats.part(Mats.cyl(0.04, 0.06, 2.2, 6), Color("1b1d33"))
	ant.position = Vector3(w * 0.3, h + 1.4, d * 0.2)
	root.add_child(ant)
	var beacon := MeshInstance3D.new()
	beacon.mesh = Mats.sphere(0.12)
	beacon.material_override = Mats.glow(Color("ff3b5c"), 3.0)
	beacon.position = ant.position + Vector3(0, 1.15, 0)
	root.add_child(beacon)
	return root


static func holo_sign(pos: Vector3, size: Vector2, color: Color, rot_y: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = Mats.energy(color, 1.4, 0.6)
	mi.position = pos
	mi.rotation.y = rot_y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
