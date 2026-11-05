extends Node
# Dev tool: builds the arena and saves screenshots from a few camera angles to user://shots/.
# Usage: godot --path . --script tools/map_preview.gd

func _ready() -> void:
	await get_tree().process_frame
	var root := Node3D.new()
	get_tree().root.add_child(root)
	var env := WorldEnvironment.new()
	env.environment = load("res://resources/environment/arena_env.tres")
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.2
	sun.light_color = Color("fff1d6")
	sun.shadow_enabled = true
	root.add_child(sun)
	var map := ArenaMap.new()
	root.add_child(map)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 38
	DirAccess.make_dir_recursive_absolute("user://shots")
	var shots := {"overview": [Vector3(0, 34, 22), Vector3(0, 0, 1)], "blue_base": [Vector3(-13, 15, 9.5), Vector3(-13, 0, 0.5)], "mid": [Vector3(-2, 15, 9.5), Vector3(-2, 0, 0.5)]}
	for name in shots:
		cam.position = shots[name][0]
		cam.look_at(shots[name][1])
		for i in 20:
			await get_tree().process_frame
		get_tree().root.get_texture().get_image().save_png("user://shots/%s.png" % name)
	print("SHOTS_OK ", ProjectSettings.globalize_path("user://shots"))
	get_tree().quit()
