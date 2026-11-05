class_name BruteModel
extends RefCounted
## BRUTE: steam-powered juggernaut. Silhouette keys: barrel body, huge spiked pauldrons, glowing furnace chest,
## exhaust stacks on the back, tiny helmeted head with a burning eye slit, and an oversized quake hammer.

const PROPS := {"hip": 0.64, "shoulder": 0.5, "torso": 0.6, "head": 0.24, "upper_arm": 0.31, "lower_arm": 0.29,
	"thigh": 0.29, "shin": 0.29, "leg_gap": 0.22, "style": &"hammer"}


static func build(r: HeroRig, d: HeroData) -> void:
	var p := PROPS
	r.build_joints(p)
	var orange := d.primary_color
	var metal := d.secondary_color
	var dark := Color("2a2633")
	var gold := d.accent_color
	var fire := Color("ff8a2b")
	r.limbs(p, metal, dark, 0.13, 0.15)
	# legs / boots
	for s in ["L", "R"]:
		r.part("Knee" + s, Mats.box(Vector3(0.32, 0.22, 0.44)), orange, Vector3(0, -p.shin - 0.02, -0.07))
		r.part("Knee" + s, Mats.box(Vector3(0.34, 0.07, 0.46)), dark, Vector3(0, -p.shin - 0.12, -0.07))
		r.part("Leg" + s, Mats.sphere(0.17, -1.0, 10, 6), orange, Vector3(0, -p.thigh, -0.06), Vector3.ZERO, Vector3(1, 0.8, 1))   # knee pad
	# hips / belt
	r.part("Hips", Mats.cyl(0.36, 0.34, 0.22, 12), Color("4a3326"), Vector3(0, 0.03, 0))
	r.part("Hips", Mats.box(Vector3(0.18, 0.16, 0.06)), gold, Vector3(0, 0.03, -0.36))
	# barrel torso + armor
	r.part("Torso", Mats.sphere(0.55, -1.0, 16, 10), orange, Vector3(0, 0.32, 0), Vector3.ZERO, Vector3(1.05, 0.95, 0.85))
	r.part("Torso", Mats.box(Vector3(0.66, 0.44, 0.16)), metal, Vector3(0, 0.4, -0.36), Vector3(-10, 0, 0))
	r.glow_part("Torso", Mats.sphere(0.14, -1.0, 10, 6), fire, 3.0, Vector3(0, 0.38, -0.46))
	r.part("Torso", Mats.torus(0.12, 0.19), gold, Vector3(0, 0.38, -0.44), Vector3(90, 0, 0))
	for x in [-0.24, 0.24]:
		for y in [0.25, 0.55]:
			r.part("Torso", Mats.sphere(0.035, -1.0, 6, 4), gold, Vector3(x, y, -0.43))
	# exhaust stacks
	for x in [-0.2, 0.2]:
		r.part("Torso", Mats.cyl(0.08, 0.1, 0.55, 10), metal, Vector3(x, 0.72, 0.36), Vector3(-12, 0, 0))
		r.glow_part("Torso", Mats.cyl(0.065, 0.065, 0.04, 10), fire, 2.5, Vector3(x, 1.0, 0.42), Vector3(-12, 0, 0))
	# pauldrons with spikes
	for s in ["L", "R"]:
		var side := -1.0 if s == "L" else 1.0
		r.part("Shoulder" + s, Mats.sphere(0.29, -1.0, 12, 8), metal, Vector3(side * 0.05, 0.04, 0), Vector3.ZERO, Vector3(1.0, 0.75, 1.0))
		r.part("Shoulder" + s, Mats.cyl(0.27, 0.3, 0.08, 12), orange, Vector3(side * 0.05, -0.08, 0))
		for k in 2:
			r.part("Shoulder" + s, Mats.prism(Vector3(0.1, 0.24, 0.1)), Color("e8e2d6"), Vector3(side * (0.1 + k * 0.1), 0.3, -0.05 + k * 0.12), Vector3(0, 0, -side * 20))
		r.part("Hand" + s, Mats.box(Vector3(0.24, 0.24, 0.24)), dark, Vector3(0, -0.04, 0))
		r.part("Elbow" + s, Mats.cyl(0.15, 0.15, 0.1, 10), gold, Vector3(0, -0.02, 0))
	# head: small, helmeted, burning eye slit, big jaw
	r.part("Head", Mats.sphere(0.24, -1.0, 12, 8), d.skin_color, Vector3(0, -0.02, 0))
	r.part("Head", Mats.box(Vector3(0.34, 0.16, 0.24)), d.skin_color, Vector3(0, -0.14, -0.08))   # jaw
	r.part("Head", Mats.sphere(0.27, -1.0, 12, 8), metal, Vector3(0, 0.08, 0.02), Vector3.ZERO, Vector3(1.05, 0.85, 1.05))  # helmet
	r.part("Head", Mats.box(Vector3(0.44, 0.08, 0.3)), metal.darkened(0.2), Vector3(0, 0.02, -0.08))
	var slit := r.glow_part("Head", Mats.box(Vector3(0.3, 0.05, 0.05)), Color("ffb347"), 3.4, Vector3(0, 0.03, -0.235))
	r.face["visor"] = slit
	for x in [-0.25, 0.25]:
		r.part("Head", Mats.prism(Vector3(0.09, 0.26, 0.09)), Color("e8e2d6"), Vector3(x, 0.15, 0.0), Vector3(-25, 0, -x * 90))   # horns
	r.part("Head", Mats.box(Vector3(0.16, 0.035, 0.03)), Color("3a1d2b"), Vector3(0, -0.15, -0.205), Vector3(0, 0, 4))   # scowl
	# quake hammer (handle along hand -Y)
	var w := "Weapon"
	r.part(w, Mats.cyl(0.055, 0.06, 1.25, 8), Color("6b4a33"), Vector3(0, -0.5, 0))
	for y in [-0.05, -0.2]:
		r.part(w, Mats.cyl(0.07, 0.07, 0.07, 8), dark, Vector3(0, y, 0))
	var head := Node3D.new()
	head.position = Vector3(0, -1.18, 0)
	r.j(w).add_child(head)
	r.joints["HammerHead"] = head
	r.part("HammerHead", Mats.box(Vector3(0.48, 0.48, 0.82)), Color("8f97ad"))
	r.part("HammerHead", Mats.box(Vector3(0.52, 0.2, 0.86)), dark)
	for z in [-0.43, 0.43]:
		r.part("HammerHead", Mats.cyl(0.27, 0.27, 0.08, 12), gold, Vector3(0, 0, z), Vector3(90, 0, 0))
	r.glow_part("HammerHead", Mats.box(Vector3(0.53, 0.06, 0.6)), fire, 2.6, Vector3(0, 0, 0))
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	head.add_child(muzzle)
	r.joints["Muzzle"] = muzzle
