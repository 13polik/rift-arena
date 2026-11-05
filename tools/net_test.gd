extends Node
# Two-process multiplayer test over real ENet sockets.
#   host:   tools/run.sh tools/net_test.tscn -- host
#   client: tools/run.sh tools/net_test.tscn -- client
# The host opens a room (bots fill the teams), waits for the client, starts a short match and plays on autopilot.
# The client joins by room code, readies up, plays with scripted touch input and reports what it received.

var role := "host"
var t := 0.0
var started := false
var snaps := 0
var events := 0
var seen := {}
var shots := [6.0, 14.0, 24.0]
var match_t := 0.0
var hp_changes := 0
var last_hp := -1.0
var done := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0] if args.size() > 0 else "host"
	var mode: ModeData = load("res://resources/modes/rift_core.tres").duplicate()
	mode.duration = 45.0
	mode.win_score = 6
	GameManager.mode_override = mode
	Settings.player_name = "HOST" if role == "host" else ("ONLINE" if role == "wsclient" else "CLIENT")
	Settings.hero = &"brute" if role == "host" else &"volt"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set_script(null)
	main.name = "Main"
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	GameManager.register_main(main)
	DirAccess.make_dir_recursive_absolute("user://shots")
	if role == "host":
		var err := Net.host()
		print("[host] hosting err=", err, " code=", Net.room_code, " ip=", Net.host_address)
		Lobby.open_room(true)
		Lobby.fill_bots = true
		GameManager.show_screen("res://ui/room_screen.tscn")
	else:
		await get_tree().create_timer(2.5).timeout
		var code := Net.encode_code("127.0.0.1", Net.DEFAULT_PORT)
		print("[client] joining code=", code, " decoded=", Net.decode_code(code))
		Net.connected.connect(func():
			print("[client] connected, my id=", Net.my_id())
			Lobby.request_join())
		Net.connection_failed.connect(func(r): print("[client] FAILED ", r); get_tree().quit(1))
		Lobby.state_changed.connect(_client_state)
		if role == "wsclient":
			print("[client] joining online server ws://127.0.0.1:24681")
			Net.join_online("ws://127.0.0.1:24681")
		else:
			Net.join(code)


func _client_state(s: Dictionary) -> void:
	print("[client] room state: ", s.players.map(func(p): return "%s(t%d %s %s)" % [p.name, p.team, p.hero, "R" if p.ready else "-"]))
	if not started and not _client_ready_sent:
		_client_ready_sent = true
		Lobby.set_ready(true)
	# on a dedicated server the first player becomes the room host and starts the match
	if not started and not _start_sent and s.host == Net.my_id() and not s.in_match:
		_start_sent = true
		print("[client] I am the room host -> START")
		Lobby.start()

var _client_ready_sent := false
var _start_sent := false


func _process(delta: float) -> void:
	t += delta
	if t > 150.0 and not done:
		print("[%s] TIMEOUT" % role)
		get_tree().quit(1)
	var mn := GameManager.match_node
	if role == "host":
		if not started and Lobby.players.size() >= 2:
			var all_ready := true
			for id in Lobby.players:
				if id != Lobby.host_id and not Lobby.players[id].ready:
					all_ready = false
			if all_ready:
				started = true
				print("[host] starting match with ", Lobby.players.size(), " humans")
				Lobby.start()
				await get_tree().process_frame
				var me := GameManager.match_node.local_hero()
				me.is_bot = true
				GameManager.match_node.bots[me.id] = BotBrain.new(GameManager.match_node, me)
		if started and mn == null and not done and GameManager.screen and GameManager.screen.name == "ResultsScreen":
			done = true
			print("[host] result: ", JSON.stringify(GameManager.last_result.score), " winner=", GameManager.last_result.winner)
			await get_tree().create_timer(2.0).timeout
			get_tree().quit()
		return
	# ---------------- client
	if mn and not started:
		started = true
		print("[client] match started; heroes=", mn.heroes.size(), " is_server=", mn.is_server)
		var orig_snap := Callable(mn.view, "on_snapshot")
	if mn and mn.view:
		if not mn.view.has_meta(&"wrapped"):
			mn.view.set_meta(&"wrapped", true)
			mn.rpc_snapshot.get_object()  # no-op: keep reference
		match_t += delta
		var me := mn.local_hero()
		# scripted thumbs: wander toward the middle and hold ATTACK (auto-aim), use skills now and then
		var touch := mn.view.touch
		var target := Vector3(0, 0, -2.0 + sin(match_t * 0.5) * 4.0)
		var d := target - me.position
		var mv := Vector3(d.x, 0, d.z).normalized() * mn.view.camera.flip
		touch.move = Vector2(mv.x, mv.z) if d.length() > 1.5 else Vector2(sin(match_t * 2.0), cos(match_t * 1.3)) * 0.8
		touch.attack_held = true
		if int(match_t * 10) % 40 == 0:
			touch.action.emit(&"ability", Vector2.ZERO, 1.0, false)
		if me.super_charge >= 1.0:
			touch.action.emit(&"super", Vector2.ZERO, 1.0, false)
		if last_hp >= 0.0 and me.hp != last_hp:
			hp_changes += 1
		last_hp = me.hp
		for h in mn.heroes.values():
			if h.get_meta(&"seen", false) and h.alive:
				seen[h.player_name] = true
		if shots.size() > 0 and match_t >= shots[0]:
			get_viewport().get_texture().get_image().save_png("user://shots/net_client_%02d.png" % int(shots[0]))
			print("[client] t=%.0f pos=%s hp=%d score=%s seen=%d snapshots_buffer=%d time=%.1f" % [match_t, me.position.snapped(Vector3(0.1, 0.1, 0.1)), me.hp, mn.mode.score, seen.size(), mn.view._snaps.size(), mn.time])
			shots.pop_front()
	if started and mn == null and not done and GameManager.screen and GameManager.screen.name == "ResultsScreen":
		done = true
		print("[client] got results: ", JSON.stringify(GameManager.last_result.score), " winner=", GameManager.last_result.winner, " hp_changes=", hp_changes, " heroes_seen=", seen.keys())
		await get_tree().create_timer(1.0).timeout
		get_viewport().get_texture().get_image().save_png("user://shots/net_client_results.png")
		get_tree().quit()
