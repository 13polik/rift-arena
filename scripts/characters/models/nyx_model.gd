class_name NyxModel
extends RefCounted
## NYX: drone conductor in light phase-armor. Silhouette keys: tall hood with two swept fins, flowing cape,
## big glowing eyes, glowing hands, and THREE drones orbiting her shoulders (they fire her seeker darts).

const PROPS := {"hip": 0.64, "shoulder": 0.26, "torso": 0.47, "head": 0.25, "upper_arm": 0.26, "lower_arm": 0.24,
	"thigh": 0.31, "shin": 0.29, "leg_gap": 0.12, "style": &"caster"}


static func build(r: HeroRig, d: HeroData) -> void:
	var p := PROPS
	r.build_joints(p)
	var violet := d.primary_color
	var dark := d.secondary_color
	var cyan := d.accent_color
	r.limbs(p, dark, dark, 0.065, 0.085)
	for s in ["L", "R"]:
		r.part("Knee" + s, Mats.prism(Vector3(0.16, 0.14, 0.32)), violet, Vector3(0, -p.shin - 0.02, -0.06), Vector3(-90, 0, 0))
		r.glow_part("Knee" + s, Mats.box(Vector3(0.14, 0.025, 0.26)), cyan, 2.4, Vector3(0, -p.shin - 0.09, -0.04))
		r.part("Leg" + s, Mats.capsule(0.095, 0.26), violet, Vector3(0, -0.12, 0))
	# torso, collar, belt, cape
	r.part("Hips", Mats.cyl(0.19, 0.22, 0.14, 12), violet, Vector3(0, 0.0, 0))
	r.glow_part("Hips", Mats.torus(0.18, 0.2), cyan, 2.2, Vector3(0, 0.07, 0))
	r.part("Torso", Mats.capsule(0.2, 0.56), violet, Vector3(0, 0.26, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
	r.part("Torso", Mats.box(Vector3(0.28, 0.24, 0.07)), dark, Vector3(0, 0.33, -0.16))
	r.glow_part("Torso", Mats.box(Vector3(0.1, 0.1, 0.02)), cyan, 2.8, Vector3(0, 0.34, -0.2), Vector3(0, 0, 45))   # drone-link emblem
	r.glow_part("Torso", Mats.box(Vector3(0.2, 0.02, 0.02)), cyan, 2.2, Vector3(0, 0.22, -0.19))
	r.part("Torso", Mats.cyl(0.15, 0.2, 0.12, 12), dark, Vector3(0, 0.5, 0))
	for x in [-0.13, 0.13]:
		var cape := r.part("Torso", Mats.box(Vector3(0.22, 0.8, 0.03)), dark, Vector3(x, 0.1, 0.2), Vector3(12, 0, x * 40))
		cape.name = "Cape"
		r.glow_part("Torso", Mats.box(Vector3(0.02, 0.78, 0.035)), cyan, 1.8, Vector3(x + signf(x) * 0.11, 0.1, 0.2), Vector3(12, 0, x * 40))
	for s in ["L", "R"]:
		r.part("Shoulder" + s, Mats.sphere(0.1, -1.0, 10, 6), violet, Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1.2, 0.8, 1.1))
		r.glow_part("Hand" + s, Mats.sphere(0.075, -1.0, 10, 6), cyan, 2.6, Vector3(0, -0.03, 0))
	# head + hood + fins + big eyes
	r.part("Head", Mats.sphere(0.27, -1.0, 16, 10), d.skin_color)
	r.part("Head", Mats.sphere(0.32, -1.0, 16, 10), dark, Vector3(0, 0.05, 0.07), Vector3.ZERO, Vector3(1.05, 1.0, 1.05))
	r.part("Head", Mats.torus(0.25, 0.31), violet, Vector3(0, 0.02, -0.12), Vector3(80, 0, 0))   # hood rim around the face
	for x in [-0.17, 0.17]:
		r.part("Head", Mats.prism(Vector3(0.08, 0.5, 0.2)), violet, Vector3(x, 0.32, 0.12), Vector3(-30, 0, -x * 70))
		r.glow_part("Head", Mats.sphere(0.04, -1.0, 6, 4), cyan, 3.0, Vector3(x * 1.55, 0.55, 0.26))
	r.eyes("Head", 0.1, 0.0, -0.22, 0.075, Color("38f5d0"), 1.2)
	r.part("Head", Mats.box(Vector3(0.06, 0.02, 0.02)), Color("6b3b6b"), Vector3(0, -0.12, -0.255))
	# drones orbit on the rig root (independent of the body animation)
	var drones := []
	for i in 3:
		var dn := Node3D.new()
		r.add_child(dn)
		var body := Mats.part(Mats.sphere(0.13, -1.0, 6, 3), Color("d8d2f0"))
		dn.add_child(body)
		r.meshes.append(body)
		var band := Mats.part(Mats.torus(0.13, 0.18), violet)
		band.rotation_degrees = Vector3(90, 0, 0)
		dn.add_child(band)
		r.meshes.append(band)
		var eye := MeshInstance3D.new()
		eye.mesh = Mats.sphere(0.06, -1.0, 8, 4)
		eye.material_override = Mats.glow(cyan, 3.0)
		eye.position = Vector3(0, 0, -0.11)
		dn.add_child(eye)
		drones.append(dn)
	r.face["drones"] = drones
	r.joints["Muzzle"] = drones[0]
	var blink := {"t": randf_range(2.0, 4.0)}
	r.face["tick"] = func(dt: float, t: float, speed: float) -> void:
		for i in drones.size():
			var a := t * 1.8 + TAU * i / drones.size()
			var dn: Node3D = drones[i]
			dn.position = Vector3(cos(a) * 0.72, 1.55 + sin(t * 3.0 + i * 2.0) * 0.1, sin(a) * 0.72 * 0.8 + 0.1)
			dn.rotation.y = -a * 0.3
		blink.t -= dt
		var eyes: Array = r.face.get("eyes", [])
		var closed: bool = blink.t < 0.0
		if blink.t < -0.12:
			blink.t = randf_range(2.0, 4.5)
		for e in eyes:
			e.scale.y = 0.15 if closed else 1.0
