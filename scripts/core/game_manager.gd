extends Node
## Autoload "GameManager": top-level flow  HOME -> (PLAY / ROOM / CHARACTER SELECT) -> MATCH -> RESULTS -> ...
## Screens are Controls added under scenes/main.tscn; the Match is a Node3D at /root/Main/Match on every peer.

const BOT_NAMES := ["Rook", "Spark", "Tess", "Quill", "Jinx", "Bolt", "Maru", "Orla", "Pike", "Zed"]

var main: Node = null
var match_node: Match = null
var screen: Control = null
var last_result := {}
var last_roster: Array = []
var mode_override: ModeData = null      # tests can shorten matches


func register_main(node: Node) -> void:
	main = node


func show_screen(scene_path: String, setup := {}) -> Control:
	if screen and is_instance_valid(screen):
		screen.queue_free()
	var s: Control = load(scene_path).instantiate()
	for k in setup:
		s.set(k, setup[k])
	main.get_node("UI").add_child(s)
	screen = s
	return s


func go_home() -> void:
	_free_match()
	show_screen("res://ui/home_screen.tscn")
	Audio.play_music(&"menu")


## Offline practice: you + bots, full 3v3.
func start_practice(hero: StringName, autopilot := false) -> void:
	Net.close()
	var roster := [{"id": 1, "name": Settings.player_name, "team": 0, "hero": String(hero), "peer": 1, "bot": autopilot, "skin": Settings.skin_for(hero)}]
	roster.append_array(make_bots(roster))
	start_match(roster, 1)


## Fill both teams up to 3 with bots, picking heroes so each team gets a varied lineup.
func make_bots(roster: Array) -> Array:
	var out := []
	var counts := [0, 0]
	var used := [[], []]
	for r in roster:
		counts[r.team] += 1
		used[r.team].append(r.hero)
	var names := BOT_NAMES.duplicate()
	names.shuffle()
	var next_id := -1
	for team in 2:
		while counts[team] < 3:
			var choices: Array = Settings.HEROES.map(func(x): return String(x)).filter(func(x): return not used[team].has(x))
			if choices.is_empty():
				choices = Settings.HEROES.map(func(x): return String(x))
			var hero: String = choices.pick_random()
			used[team].append(hero)
			out.append({"id": next_id, "name": "BOT " + names.pop_back(), "team": team, "hero": hero, "bot": true})
			next_id -= 1
			counts[team] += 1
	return out


func start_match(roster: Array, my_id: int) -> void:
	last_roster = roster
	if screen and is_instance_valid(screen):
		screen.queue_free()
		screen = null
	_free_match()
	match_node = Match.new()
	main.add_child(match_node)
	match_node.start(roster, my_id, mode_override)
	match_node.finished.connect(_on_match_finished)


func _on_match_finished(res: Dictionary) -> void:
	last_result = res
	var my_team := 0
	if match_node and match_node.local_hero():
		my_team = match_node.local_hero().team
	_free_match()
	show_screen("res://ui/results_screen.tscn", {"result": res, "my_team": my_team})
	Audio.play_music(&"menu")


func leave_match() -> void:
	Net.close()
	go_home()


func _free_match() -> void:
	if match_node and is_instance_valid(match_node):
		match_node.queue_free()
	match_node = null
