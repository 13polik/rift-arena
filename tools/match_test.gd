extends Node
# Automated vertical-slice test: full 3v3 offline match (local hero on autopilot), screenshots + stats.
# Usage: tools/run.sh tools/match_test.tscn -- <hero> <duration> <win_score>
var shots := [3.5, 9.0, 16.0, 24.0, 34.0, 46.0]
var t := 0.0
var fps_samples: Array[float] = []
var events := {}
var frames_since := 0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var hero := args[0] if args.size() > 0 else "volt"
	var mode: ModeData = load("res://resources/modes/rift_core.tres").duplicate()
	mode.duration = float(args[1]) if args.size() > 1 else 60.0
	mode.win_score = int(args[2]) if args.size() > 2 else 8
	GameManager.mode_override = mode
	if args.size() > 3:
		Settings.quality = int(args[3]) as Settings.Quality
		Settings.apply_engine_settings()
	print("QUALITY ", Settings.quality)
	Prof.enabled = true
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set_script(null)
	main.name = "Main"
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.register_main(main)
	GameManager.start_practice(StringName(hero), true)
	GameManager.match_node.view.on_events  # touch
	DirAccess.make_dir_recursive_absolute("user://shots")

func _process(delta: float) -> void:
	t += delta
	frames_since += 1
	if t > 2.0:
		fps_samples.append(Engine.get_frames_per_second())
	var mn := GameManager.match_node
	if mn and not mn.has_meta(&"hooked"):
		mn.set_meta(&"hooked", true)
		var orig := mn.view
		mn.finished.connect(func(r): print("RESULT ", JSON.stringify(r)))
	if mn and mn.view and not mn.view.has_meta(&"ev"):
		mn.view.set_meta(&"ev", true)
	if shots.size() > 0 and t >= shots[0]:
		var name := "match_%02d" % int(shots[0])
		shots.pop_front()
		get_viewport().get_texture().get_image().save_png("user://shots/%s.png" % name)
		if mn:
			var s := []
			for h in mn.heroes.values():
				s.append("%s(%s t%d hp%d c%d %s)" % [h.player_name, h.data.id, h.team, h.hp, h.carried, "A" if h.alive else "D"])
			print("t=%.1f phase=%d score=%s  %s" % [mn.time, mn.phase, str(mn.mode.score), " ".join(s)])
			print("  perf: fps=%d draws=%d prims=%d objs=%d process=%.1fms physics=%.1fms" % [Engine.get_frames_per_second(),
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
			print("  prof: ", Prof.report(frames_since))
			frames_since = 0
	if GameManager.screen and GameManager.screen.name == "ResultsScreen" and not has_meta(&"done"):
		set_meta(&"done", true)
		await get_tree().create_timer(1.0).timeout
		get_viewport().get_texture().get_image().save_png("user://shots/results.png")
		var avg := 0.0
		for f in fps_samples: avg += f
		print("FPS avg=%.1f min=%.1f" % [avg / maxf(1, fps_samples.size()), fps_samples.min() if fps_samples.size() else 0.0])
		get_tree().quit()
