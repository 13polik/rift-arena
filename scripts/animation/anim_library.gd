class_name AnimLibrary
extends RefCounted
## Generates the full animation set (AnimationLibrary) for a HeroRig.
## Each animation is a list of keyframes; a keyframe is a set of joint rotation OFFSETS (degrees) from the
## style's rest pose + hip height/forward offsets. Every joint is keyed in every animation so AnimationTree
## blends are always clean (no joint left behind in an old pose).
##
## Styles: &"gun" (Volt), &"hammer" (Brute), &"caster" (Nyx).

const PATHS := {
	"Hips": "Rig/Hips", "Torso": "Rig/Hips/Torso", "Head": "Rig/Hips/Torso/Head",
	"ShoulderL": "Rig/Hips/Torso/ShoulderL", "ElbowL": "Rig/Hips/Torso/ShoulderL/ElbowL",
	"ShoulderR": "Rig/Hips/Torso/ShoulderR", "ElbowR": "Rig/Hips/Torso/ShoulderR/ElbowR",
	"Weapon": "Rig/Hips/Torso/ShoulderR/ElbowR/HandR/Weapon",
	"LegL": "Rig/Hips/LegL", "KneeL": "Rig/Hips/LegL/KneeL",
	"LegR": "Rig/Hips/LegR", "KneeR": "Rig/Hips/LegR/KneeR",
}

const NAMES: Array[StringName] = [&"idle", &"walk", &"run", &"attack", &"ability", &"super", &"hit", &"death", &"respawn", &"victory", &"defeat"]


static func rest(style: StringName) -> Dictionary:
	var r := {}
	for j in PATHS:
		r[j] = Vector3.ZERO
	match style:
		&"gun":
			r["ShoulderR"] = Vector3(38, 0, 8); r["ElbowR"] = Vector3(42, 0, 0)
			r["ShoulderL"] = Vector3(6, 0, -14); r["ElbowL"] = Vector3(22, 0, 0)
		&"hammer":
			r["ShoulderR"] = Vector3(22, 0, 16); r["ElbowR"] = Vector3(18, 0, 0); r["Weapon"] = Vector3(0, 0, 0)
			r["ShoulderL"] = Vector3(28, 0, -18); r["ElbowL"] = Vector3(40, 0, 0)
			r["Torso"] = Vector3(-6, 0, 0)
		&"caster":
			r["ShoulderL"] = Vector3(14, 0, -24); r["ElbowL"] = Vector3(34, 0, 0)
			r["ShoulderR"] = Vector3(14, 0, 24); r["ElbowR"] = Vector3(34, 0, 0)
	return r


static func build(style: StringName, hip: float) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var R := rest(style)
	var defs := _defs(style)
	for n in defs:
		var d: Dictionary = defs[n]
		lib.add_animation(n, _make(d.len, d.loop, d.keys, R, hip))
	return lib


## keys: Array of [time, {joint: offset_deg}, hip_dy, hip_dz]
static func _make(length: float, loop: bool, keys: Array, R: Dictionary, hip: float) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for joint in PATHS:
		var idx := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(idx, NodePath(PATHS[joint] + ":rotation"))
		a.track_set_interpolation_type(idx, Animation.INTERPOLATION_CUBIC)
		a.track_set_interpolation_loop_wrap(idx, loop)
		for k in keys:
			var off: Vector3 = k[1].get(joint, Vector3.ZERO)
			a.track_insert_key(idx, k[0], (R[joint] + off) * (PI / 180.0))
	var pidx := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(pidx, NodePath("Rig/Hips:position"))
	a.track_set_interpolation_type(pidx, Animation.INTERPOLATION_CUBIC)
	a.track_set_interpolation_loop_wrap(pidx, loop)
	for k in keys:
		var dy: float = k[2] if k.size() > 2 else 0.0
		var dz: float = k[3] if k.size() > 3 else 0.0
		a.track_insert_key(pidx, k[0], Vector3(0, hip + dy, dz))
	return a


static func V(x: float, y := 0.0, z := 0.0) -> Vector3:
	return Vector3(x, y, z)


static func _defs(style: StringName) -> Dictionary:
	var gun := style == &"gun"
	var ham := style == &"hammer"
	var arm := 0.35 if gun else 1.0     # gunners keep the weapon arm steady while moving
	var d := {}
	# ---------------- locomotion ----------------
	d[&"idle"] = {"len": 1.6, "loop": true, "keys": [
		[0.0, {}, 0.0],
		[0.8, {"Torso": V(3), "Head": V(-4, 3), "ShoulderL": V(5, 0, -3), "ShoulderR": V(4 * arm, 0, 2), "ElbowL": V(6)}, -0.025],
		[1.6, {}, 0.0]]}
	var w := 28.0
	d[&"walk"] = {"len": 0.72, "loop": true, "keys": [
		[0.0, {"LegL": V(w), "LegR": V(-w * 0.8), "KneeR": V(-28), "KneeL": V(-4), "ShoulderL": V(-20), "ShoulderR": V(20 * arm), "Torso": V(-3, 6)}, 0.0],
		[0.18, {"KneeR": V(-48), "Torso": V(-3, 0)}, 0.035],
		[0.36, {"LegR": V(w), "LegL": V(-w * 0.8), "KneeL": V(-28), "KneeR": V(-4), "ShoulderR": V(-20 * arm), "ShoulderL": V(20), "Torso": V(-3, -6)}, 0.0],
		[0.54, {"KneeL": V(-48), "Torso": V(-3, 0)}, 0.035],
		[0.72, {"LegL": V(w), "LegR": V(-w * 0.8), "KneeR": V(-28), "KneeL": V(-4), "ShoulderL": V(-20), "ShoulderR": V(20 * arm), "Torso": V(-3, 6)}, 0.0]]}
	var rr := 46.0
	var lean := -14.0 if not ham else -18.0
	d[&"run"] = {"len": 0.5, "loop": true, "keys": [
		[0.0, {"LegL": V(rr), "LegR": V(-rr * 0.8), "KneeR": V(-60), "KneeL": V(-10), "ShoulderL": V(-38), "ShoulderR": V(36 * arm), "ElbowL": V(30), "Torso": V(lean, 9), "Head": V(-lean * 0.6)}, -0.02],
		[0.125, {"KneeR": V(-80), "LegR": V(0), "LegL": V(10), "ShoulderL": V(0), "ShoulderR": V(0), "ElbowL": V(30), "Torso": V(lean, 0), "Head": V(-lean * 0.6)}, 0.06],
		[0.25, {"LegR": V(rr), "LegL": V(-rr * 0.8), "KneeL": V(-60), "KneeR": V(-10), "ShoulderR": V(-38 * arm), "ShoulderL": V(36), "ElbowL": V(30), "Torso": V(lean, -9), "Head": V(-lean * 0.6)}, -0.02],
		[0.375, {"KneeL": V(-80), "LegL": V(0), "LegR": V(10), "ShoulderL": V(0), "ShoulderR": V(0), "ElbowL": V(30), "Torso": V(lean, 0), "Head": V(-lean * 0.6)}, 0.06],
		[0.5, {"LegL": V(rr), "LegR": V(-rr * 0.8), "KneeR": V(-60), "KneeL": V(-10), "ShoulderL": V(-38), "ShoulderR": V(36 * arm), "ElbowL": V(30), "Torso": V(lean, 9), "Head": V(-lean * 0.6)}, -0.02]]}
	# ---------------- combat ----------------
	match style:
		&"gun":
			var aim := {"ShoulderR": V(48), "ElbowR": V(-38), "Torso": V(0, -14), "Head": V(0, 10), "ShoulderL": V(14, 0, -6)}
			var kick := {"ShoulderR": V(36), "ElbowR": V(-30), "Torso": V(4, -14), "Head": V(4, 10), "ShoulderL": V(14, 0, -6)}
			d[&"attack"] = {"len": 0.3, "loop": false, "keys": [[0.0, aim, 0.0], [0.03, kick, 0.0, 0.03], [0.075, aim, 0.0], [0.105, kick, 0.0, 0.03], [0.15, aim, 0.0], [0.18, kick, 0.0, 0.03], [0.3, aim, 0.0]]}
			d[&"ability"] = {"len": 0.42, "loop": false, "keys": [
				[0.0, {}, 0.0],
				[0.06, {"Torso": V(-28), "ShoulderL": V(-40), "ShoulderR": V(-30), "LegL": V(35), "KneeL": V(-55), "LegR": V(-25), "KneeR": V(-45)}, -0.13],
				[0.16, {"Torso": V(-38), "ShoulderL": V(-60, 0, -20), "ShoulderR": V(-50, 0, 20), "LegL": V(-20), "LegR": V(30), "KneeR": V(-30)}, 0.06, -0.1],
				[0.42, {}, 0.0]]}
			var two := {"ShoulderR": V(48), "ElbowR": V(-40), "ShoulderL": V(80, 0, 30), "ElbowL": V(-12), "LegL": V(25), "LegR": V(-25), "KneeR": V(-25), "Torso": V(-6)}
			d[&"super"] = {"len": 0.75, "loop": false, "keys": [
				[0.0, {}, 0.0], [0.12, two, -0.07], [0.26, two, -0.08],
				[0.32, {"ShoulderR": V(18), "ElbowR": V(-30), "ShoulderL": V(55, 0, 30), "Torso": V(20), "Head": V(12), "LegL": V(25), "LegR": V(-25)}, -0.03, 0.14],
				[0.75, {}, 0.0]]}
		&"hammer":
			d[&"attack"] = {"len": 0.5, "loop": false, "keys": [
				[0.0, {}, 0.0],
				[0.08, {"ShoulderR": V(125), "ElbowR": V(-10), "ShoulderL": V(100), "Torso": V(12, 14), "Head": V(-6)}, 0.03],
				[0.16, {"ShoulderR": V(55), "ElbowR": V(-15), "ShoulderL": V(45), "Torso": V(-24, -12), "LegL": V(22), "LegR": V(-16), "KneeR": V(-22)}, -0.09],
				[0.3, {"ShoulderR": V(50), "ElbowR": V(-15), "ShoulderL": V(40), "Torso": V(-20, -10), "LegL": V(20), "LegR": V(-14)}, -0.08],
				[0.5, {}, 0.0]]}
			d[&"ability"] = {"len": 0.45, "loop": true, "keys": [
				[0.0, {"Torso": V(-32), "ShoulderR": V(35), "ShoulderL": V(65), "LegL": V(40), "LegR": V(-35), "KneeR": V(-50), "Head": V(20)}, -0.05],
				[0.11, {"Torso": V(-32), "ShoulderR": V(35), "ShoulderL": V(65), "LegL": V(0), "LegR": V(0), "KneeL": V(-60), "Head": V(20)}, 0.03],
				[0.22, {"Torso": V(-32), "ShoulderR": V(35), "ShoulderL": V(65), "LegR": V(40), "LegL": V(-35), "KneeL": V(-50), "Head": V(20)}, -0.05],
				[0.33, {"Torso": V(-32), "ShoulderR": V(35), "ShoulderL": V(65), "LegL": V(0), "LegR": V(0), "KneeR": V(-60), "Head": V(20)}, 0.03],
				[0.45, {"Torso": V(-32), "ShoulderR": V(35), "ShoulderL": V(65), "LegL": V(40), "LegR": V(-35), "KneeR": V(-50), "Head": V(20)}, -0.05]]}
			var over := {"ShoulderR": V(150), "ElbowR": V(-5), "ShoulderL": V(140), "ElbowL": V(-20), "Torso": V(14), "Head": V(-10), "LegL": V(10), "LegR": V(-10)}
			var slam := {"ShoulderR": V(60), "ElbowR": V(-20), "ShoulderL": V(50), "Torso": V(-38), "Head": V(18), "LegL": V(45), "KneeL": V(-65), "LegR": V(-30), "KneeR": V(-25)}
			d[&"super"] = {"len": 0.8, "loop": false, "keys": [
				[0.0, {}, 0.0], [0.14, {"Torso": V(-20), "KneeL": V(-50), "KneeR": V(-50), "LegL": V(30), "LegR": V(30)}, -0.16],
				[0.3, over, 0.55], [0.42, slam, -0.22], [0.62, slam, -0.2], [0.8, {}, 0.0]]}
		_:
			d[&"attack"] = {"len": 0.36, "loop": false, "keys": [
				[0.0, {}, 0.0],
				[0.07, {"ShoulderR": V(70), "ElbowR": V(-34), "ShoulderL": V(55), "ElbowL": V(-20), "Torso": V(-6, -8)}, 0.02],
				[0.16, {"ShoulderR": V(76), "ElbowR": V(-38), "ShoulderL": V(60), "ElbowL": V(-25), "Torso": V(-8, -8)}, 0.02],
				[0.36, {}, 0.0]]}
			d[&"ability"] = {"len": 0.5, "loop": false, "keys": [
				[0.0, {}, 0.0],
				[0.16, {"ShoulderL": V(115, 0, 10), "ShoulderR": V(115, 0, -10), "ElbowL": V(-20), "ElbowR": V(-20), "Torso": V(8), "Head": V(-10)}, 0.06],
				[0.3, {"ShoulderL": V(65, 0, 15), "ShoulderR": V(65, 0, -15), "Torso": V(-12), "Head": V(5)}, -0.04],
				[0.5, {}, 0.0]]}
			d[&"super"] = {"len": 0.8, "loop": false, "keys": [
				[0.0, {}, 0.0],
				[0.22, {"ShoulderL": V(150, 0, -40), "ShoulderR": V(150, 0, 40), "ElbowL": V(-10), "ElbowR": V(-10), "Head": V(-18), "Torso": V(10)}, 0.14],
				[0.45, {"ShoulderL": V(25, 0, -80), "ShoulderR": V(25, 0, 80), "Head": V(5), "Torso": V(-6), "KneeL": V(-25), "KneeR": V(-25)}, -0.06],
				[0.8, {}, 0.0]]}
	# ---------------- reactions / states ----------------
	d[&"hit"] = {"len": 0.3, "loop": false, "keys": [
		[0.0, {}, 0.0],
		[0.06, {"Torso": V(18, 6), "Head": V(16), "ShoulderL": V(-25, 0, -10), "ShoulderR": V(-15, 0, 10)}, -0.03, 0.07],
		[0.3, {}, 0.0]]}
	d[&"death"] = {"len": 1.0, "loop": false, "keys": [
		[0.0, {}, 0.0],
		[0.15, {"Torso": V(18), "Head": V(22), "ShoulderL": V(60, 0, -20), "ShoulderR": V(60, 0, 20)}, 0.06],
		[0.55, {"Hips": V(82), "Torso": V(10), "Head": V(15), "ShoulderL": V(150, 0, -50), "ShoulderR": V(150, 0, 50), "LegL": V(35), "LegR": V(12), "KneeL": V(-20)}, -0.45, 0.25],
		[0.7, {"Hips": V(86), "Torso": V(5), "Head": V(5), "ShoulderL": V(160, 0, -60), "ShoulderR": V(160, 0, 60), "LegL": V(25), "LegR": V(5)}, -0.4, 0.3],
		[1.0, {"Hips": V(88), "Torso": V(4), "Head": V(0), "ShoulderL": V(165, 0, -65), "ShoulderR": V(165, 0, 65), "LegL": V(22), "LegR": V(4)}, -0.45, 0.3]]}
	d[&"respawn"] = {"len": 0.7, "loop": false, "keys": [
		[0.0, {"Torso": V(-30), "Head": V(-20), "LegL": V(60), "LegR": V(60), "KneeL": V(-85), "KneeR": V(-85), "ShoulderL": V(-10), "ShoulderR": V(-10)}, -0.3],
		[0.32, {"Torso": V(8), "Head": V(-12), "ShoulderL": V(70, 0, -60), "ShoulderR": V(70, 0, 60)}, 0.16],
		[0.7, {}, 0.0]]}
	d[&"victory"] = {"len": 1.0, "loop": true, "keys": [
		[0.0, {"ShoulderR": V(120), "ShoulderL": V(60, 0, -30)}, 0.0],
		[0.25, {"ShoulderR": V(165), "ElbowR": V(-15), "ShoulderL": V(110, 0, -35), "Head": V(-12)}, 0.28],
		[0.5, {"ShoulderR": V(120), "ShoulderL": V(60, 0, -30)}, 0.0],
		[0.75, {"ShoulderL": V(165, 0, -10), "ElbowL": V(-15), "ShoulderR": V(110, 0, 35), "Head": V(-12)}, 0.28],
		[1.0, {"ShoulderR": V(120), "ShoulderL": V(60, 0, -30)}, 0.0]]}
	d[&"defeat"] = {"len": 2.0, "loop": true, "keys": [
		[0.0, {"Torso": V(-24), "Head": V(-26), "ShoulderL": V(-8, 0, 6), "ShoulderR": V(-8, 0, -6), "ElbowL": V(-15), "ElbowR": V(-15)}, -0.05],
		[1.0, {"Torso": V(-28, 4), "Head": V(-16, -10), "ShoulderL": V(-6, 0, 8), "ShoulderR": V(-6, 0, -8), "ElbowL": V(-15), "ElbowR": V(-15)}, -0.07],
		[2.0, {"Torso": V(-24), "Head": V(-26), "ShoulderL": V(-8, 0, 6), "ShoulderR": V(-8, 0, -6), "ElbowL": V(-15), "ElbowR": V(-15)}, -0.05]]}
	return d
