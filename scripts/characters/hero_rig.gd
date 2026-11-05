class_name HeroRig
extends Node3D
## Joint hierarchy shared by all heroes (forward = -Z, right = +X). Animations target these joint names,
## so every hero gets the same animation set while each model hangs its own meshes on the joints.
##
## Rig
##  └ Hips ─┬ Torso ─┬ Head
##          │        ├ ShoulderL ─ ElbowL ─ HandL
##          │        └ ShoulderR ─ ElbowR ─ HandR ─ Weapon
##          ├ LegL ─ KneeL
##          └ LegR ─ KneeR

var joints := {}
var meshes: Array[GeometryInstance3D] = []   # every part, for hit flash / fade
var face := {}                                # optional expressive bits (eyes, brows, jaw) for procedural tweaks


## p: proportions. hip (height), shoulder (half width), torso (hips->shoulder), head (neck height),
## upper / lower arm length, thigh / shin length, leg_gap
func build_joints(p: Dictionary) -> void:
	name = "Rig"
	var hips := _joint("Hips", self, Vector3(0, p.hip, 0))
	var torso := _joint("Torso", hips, Vector3(0, 0.08, 0))
	_joint("Head", torso, Vector3(0, p.torso + p.head, 0))
	for side in [-1.0, 1.0]:
		var s := "L" if side < 0.0 else "R"
		var sh := _joint("Shoulder" + s, torso, Vector3(side * p.shoulder, p.torso, 0))
		var el := _joint("Elbow" + s, sh, Vector3(0, -p.upper_arm, 0))
		var hand := _joint("Hand" + s, el, Vector3(0, -p.lower_arm, 0))
		if s == "R":
			_joint("Weapon", hand, Vector3.ZERO)
		var leg := _joint("Leg" + s, hips, Vector3(side * p.leg_gap, 0, 0))
		_joint("Knee" + s, leg, Vector3(0, -p.thigh, 0))
		joints["Foot" + s + "_len"] = p.shin


func _joint(n: String, parent: Node3D, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.name = n
	j.position = pos
	parent.add_child(j)
	joints[n] = j
	return j


func j(n: String) -> Node3D:
	return joints[n]


## Attach a toon-shaded part to a joint.
func part(joint: String, mesh: Mesh, color: Color, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scl := Vector3.ONE, glow := Color(0, 0, 0, 0)) -> MeshInstance3D:
	var mi := Mats.part(mesh, color, glow)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	joints[joint].add_child(mi)
	meshes.append(mi)
	return mi


## Attach an unshaded glowing part (visors, energy coils).
func glow_part(joint: String, mesh: Mesh, color: Color, energy := 2.2, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Mats.glow(color, energy)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta(&"glow_color", color)
	joints[joint].add_child(mi)
	return mi


## Performance: merge all parts hanging directly on each joint into ONE mesh (vertex colors carry the part colors,
## vertex alpha < 1 marks glowing parts). A hero drops from ~45 draw calls to ~14 while staying fully animated.
func bake() -> void:
	var merged: Array[GeometryInstance3D] = []
	for jn in joints:
		var joint = joints[jn]
		if not (joint is Node3D):
			continue
		var parts: Array[MeshInstance3D] = []
		for c in joint.get_children():
			if c is MeshInstance3D and not c.has_meta(&"keep"):
				parts.append(c)
		if parts.size() < 2:
			continue
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var cols := PackedColorArray()
		var idx := PackedInt32Array()
		for mi in parts:
			var col := Color.WHITE
			if mi.has_meta(&"glow_color"):
				col = mi.get_meta(&"glow_color")
				col.a = 0.0
			else:
				var alb = mi.get_instance_shader_parameter(&"albedo")
				col = alb if alb is Color else Color.WHITE
				var g = mi.get_instance_shader_parameter(&"glow")
				col.a = (1.0 - clampf(g.a / 1.3, 0.0, 0.9)) if g is Color else 1.0
			var arr := mi.mesh.surface_get_arrays(0)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var ind = arr[Mesh.ARRAY_INDEX]
			var xf: Transform3D = mi.transform
			var nb := xf.basis.inverse().transposed()
			var base := verts.size()
			for i in v.size():
				verts.append(xf * v[i])
				norms.append((nb * n[i]).normalized())
				cols.append(col)
			if ind == null or (ind as PackedInt32Array).is_empty():
				for i in v.size():
					idx.append(base + i)
			else:
				for k in ind:
					idx.append(base + k)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_COLOR] = cols
		arrays[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var out := MeshInstance3D.new()
		out.name = "Baked"
		out.mesh = am
		out.material_override = Mats.toon()
		joint.add_child(out)
		merged.append(out)
		for mi in parts:
			meshes.erase(mi)
			mi.queue_free()
	meshes.append_array(merged)


## Standard limbs (capsules) so models only need to add their signature pieces.
func limbs(p: Dictionary, arm_col: Color, leg_col: Color, arm_r: float, leg_r: float) -> void:
	for s in ["L", "R"]:
		part("Shoulder" + s, Mats.capsule(arm_r, p.upper_arm + arm_r), arm_col, Vector3(0, -p.upper_arm * 0.5, 0))
		part("Elbow" + s, Mats.capsule(arm_r * 0.92, p.lower_arm + arm_r), arm_col, Vector3(0, -p.lower_arm * 0.5, 0))
		part("Leg" + s, Mats.capsule(leg_r, p.thigh + leg_r), leg_col, Vector3(0, -p.thigh * 0.5, 0))
		part("Knee" + s, Mats.capsule(leg_r * 0.92, p.shin + leg_r * 0.5), leg_col, Vector3(0, -p.shin * 0.5, 0))


## Cartoon eyes: white + pupil + highlight. Returns the eye pivots so they can blink.
func eyes(joint: String, spacing: float, y: float, z: float, size: float, iris: Color, iris_glow := 0.0) -> Array:
	var out := []
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * spacing, y, z)
		joints[joint].add_child(pivot)
		var white := Mats.part(Mats.sphere(size, -1.0, 12, 8), Color("fbfbff"))
		white.scale = Vector3(1, 1.15, 0.55)
		pivot.add_child(white)
		meshes.append(white)
		var pupil := Mats.part(Mats.sphere(size * 0.55, -1.0, 10, 6), iris, Color(iris.r, iris.g, iris.b, iris_glow))
		pupil.position = Vector3(0, 0, -size * 0.38)
		pupil.scale = Vector3(1, 1.15, 0.5)
		pivot.add_child(pupil)
		meshes.append(pupil)
		var hl := MeshInstance3D.new()
		hl.mesh = Mats.sphere(size * 0.18, -1.0, 6, 4)
		hl.material_override = Mats.glow(Color.WHITE, 1.5)
		hl.position = Vector3(size * 0.25, size * 0.3, -size * 0.55)
		pivot.add_child(hl)
		out.append(pivot)
	face["eyes"] = out
	return out
