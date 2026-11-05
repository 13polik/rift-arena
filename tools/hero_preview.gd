extends Node
# Dev tool: renders each hero in several animation states to user://shots/hero_<id>_<state>.png
# Usage: godot --path . tools/hero_preview.tscn  (optional: -- volt brute nyx)

func _ready() -> void:
	var ids := OS.get_cmdline_user_args()
	if ids.is_empty():
		ids = ["volt"]
	var root := Node3D.new()
	add_child(root)
	var env := WorldEnvironment.new()
	env.environment = load("res://resources/environment/arena_env.tres")
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("fff1d6")
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor_mi.mesh = pm
	var gm := ShaderMaterial.new()
	gm.shader = Mats.GROUND
	floor_mi.material_override = gm
	floor_mi.position = Vector3(-8, 0, 0)
	root.add_child(floor_mi)
	var cam := Camera3D.new()
	cam.fov = 30
	root.add_child(cam)
	DirAccess.make_dir_recursive_absolute("user://shots")
	for id in ids:
		var v := HeroVisual.new()
		root.add_child(v)
		v.setup(Settings.hero_data(StringName(id)), true, true, id.to_upper())
		v.set_hp(0.7)
		v.set_facing(Vector3(0.5, 0, 1).normalized(), true)   # 3/4 view toward camera
		var states := [["idle", 0.0], ["run", 1.0], ["attack", -1.0], ["ability", -1.0], ["super", -1.0], ["hit", -2.0], ["death", -3.0]]
		for st in states:
			cam.position = Vector3(0, 3.2, 5.2)
			cam.look_at(Vector3(0, 1.0, 0))
			if st[1] >= 0.0:
				v.anim.set_locomotion(st[1], 1.0)
				for i in 40:
					await get_tree().process_frame
			elif st[1] == -1.0:
				v.anim.play_action(StringName(st[0]))
				for i in (9 if st[0] != "super" else 18):
					await get_tree().process_frame
			elif st[1] == -2.0:
				v.hit(1.0)
				for i in 3:
					await get_tree().process_frame
			else:
				v.die()
				for i in 50:
					await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("user://shots/hero_%s_%s.png" % [id, st[0]])
		v.queue_free()
	print("HERO_SHOTS_OK")
	get_tree().quit()
