class_name VoltModel
extends RefCounted
## VOLT: slim flight-suit runner. Silhouette keys: spiky electric-yellow hair, glowing visor band,
## jet pack with twin thrusters, long arc-blaster with glowing coils.

const PROPS := {"hip": 0.62, "shoulder": 0.29, "torso": 0.5, "head": 0.24, "upper_arm": 0.27, "lower_arm": 0.25,
	"thigh": 0.29, "shin": 0.27, "leg_gap": 0.13, "style": &"gun"}


static func build(r: HeroRig, d: HeroData) -> void:
	var p := PROPS
	r.build_joints(p)
	var suit := d.primary_color
	var dark := d.secondary_color
	var white := Color("eef6ff")
	var cyan := Color("6ff6ff")
	r.limbs(p, dark, dark, 0.075, 0.095)
	# --- legs / boots
	for s in ["L", "R"]:
		r.part("Knee" + s, Mats.box(Vector3(0.19, 0.15, 0.3)), suit, Vector3(0, -p.shin - 0.02, -0.05))
		r.glow_part("Knee" + s, Mats.box(Vector3(0.2, 0.03, 0.31)), cyan, 2.5, Vector3(0, -p.shin - 0.095, -0.05))
		r.part("Leg" + s, Mats.capsule(0.105, 0.22), suit, Vector3(0, -0.1, -0.01))   # thigh armor
	# --- hips / torso
	r.part("Hips", Mats.cyl(0.21, 0.2, 0.13, 12), Color("1b1f3d"), Vector3(0, 0.02, 0))
	r.glow_part("Hips", Mats.box(Vector3(0.09, 0.07, 0.03)), cyan, 2.5, Vector3(0, 0.03, -0.21))
	r.part("Torso", Mats.capsule(0.235, 0.62), suit, Vector3(0, 0.27, 0), Vector3.ZERO, Vector3(1.08, 1, 0.85))
	r.part("Torso", Mats.box(Vector3(0.36, 0.24, 0.08)), white, Vector3(0, 0.34, -0.19), Vector3(-8, 0, 0))
	r.glow_part("Torso", Mats.box(Vector3(0.3, 0.03, 0.02)), cyan, 2.8, Vector3(0, 0.29, -0.235))
	r.glow_part("Torso", Mats.box(Vector3(0.03, 0.14, 0.02)), cyan, 2.8, Vector3(0, 0.38, -0.235))
	r.part("Torso", Mats.cyl(0.16, 0.2, 0.1, 12), dark, Vector3(0, 0.53, 0))   # collar
	# jet pack
	r.part("Torso", Mats.box(Vector3(0.32, 0.36, 0.16)), Color("2a3160"), Vector3(0, 0.3, 0.24))
	for x in [-0.1, 0.1]:
		r.part("Torso", Mats.cyl(0.06, 0.075, 0.2, 10), white, Vector3(x, 0.12, 0.3))
		r.glow_part("Torso", Mats.sphere(0.055, -1.0, 8, 4), cyan, 3.0, Vector3(x, 0.0, 0.3))
	# shoulder pads + gloves
	for s in ["L", "R"]:
		r.part("Shoulder" + s, Mats.sphere(0.13, -1.0, 12, 6), suit, Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1.15, 0.8, 1.1))
		r.part("Hand" + s, Mats.sphere(0.085, -1.0, 10, 6), white, Vector3(0, -0.03, 0))
		r.part("Elbow" + s, Mats.cyl(0.09, 0.085, 0.12, 10), white, Vector3(0, -p.lower_arm * 0.75, 0))   # cuff
	# --- head
	r.part("Head", Mats.sphere(0.29, -1.0, 16, 10), d.skin_color)
	r.part("Head", Mats.sphere(0.3, -1.0, 16, 10), Color("1d2348"), Vector3(0, 0.08, 0.05), Vector3.ZERO, Vector3(1.0, 0.78, 0.98))
	# electric hair spikes
	var spikes := [[Vector3(0, 0.27, -0.12), Vector3(-55, 0, 0), 0.26], [Vector3(-0.13, 0.25, -0.06), Vector3(-45, 0, 25), 0.22],
		[Vector3(0.13, 0.25, -0.06), Vector3(-45, 0, -25), 0.22], [Vector3(0, 0.3, 0.08), Vector3(-15, 0, 0), 0.24],
		[Vector3(-0.17, 0.2, 0.1), Vector3(-10, 0, 40), 0.2], [Vector3(0.17, 0.2, 0.1), Vector3(-10, 0, -40), 0.2]]
	for sp in spikes:
		r.part("Head", Mats.prism(Vector3(0.14, sp[2], 0.12)), d.accent_color, sp[0], sp[1], Vector3.ONE, Color(1, 0.95, 0.4, 0.35))
	# visor band (signature) + frame
	r.part("Head", Mats.box(Vector3(0.5, 0.15, 0.1)), Color("161a33"), Vector3(0, 0.03, -0.235))
	var visor := r.glow_part("Head", Mats.box(Vector3(0.44, 0.09, 0.05)), Color("7ff9ff"), 3.2, Vector3(0, 0.035, -0.28))
	r.face["visor"] = visor
	for x in [-0.29, 0.29]:
		r.part("Head", Mats.prism(Vector3(0.05, 0.2, 0.14)), suit, Vector3(x, 0.08, 0.02), Vector3(0, 0, -20 if x < 0 else 20))
	r.part("Head", Mats.box(Vector3(0.1, 0.03, 0.02)), Color("5a2335"), Vector3(0, -0.12, -0.272), Vector3(0, 0, 0))   # grin
	# --- arc blaster (barrel along the hand's -Y so arm angle drives aim)
	var w := "Weapon"
	r.part(w, Mats.box(Vector3(0.13, 0.5, 0.17)), Color("262b4d"), Vector3(0, -0.18, -0.03))
	r.part(w, Mats.box(Vector3(0.15, 0.2, 0.19)), white, Vector3(0, -0.06, -0.03))
	r.part(w, Mats.cyl(0.045, 0.055, 0.3, 10), Color("3a4170"), Vector3(0, -0.5, -0.03))
	r.part(w, Mats.box(Vector3(0.08, 0.14, 0.1)), Color("1b1f3d"), Vector3(0, 0.04, 0.07))
	for y in [-0.32, -0.42]:
		r.glow_part(w, Mats.torus(0.06, 0.1), cyan, 2.8, Vector3(0, y, -0.03))
	var tip := r.glow_part(w, Mats.sphere(0.06, -1.0, 8, 4), Color("bffcff"), 3.5, Vector3(0, -0.67, -0.03))
	r.face["muzzle_glow"] = tip
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, -0.7, -0.03)
	r.j("Weapon").add_child(muzzle)
	r.joints["Muzzle"] = muzzle
