extends Node
## Autoload "Lobby": the room before a match. Server-authoritative: clients only send requests,
## the server validates and broadcasts the room state to everyone.
##   create room (host) -> join by code -> pick TEAM / HERO -> READY -> host presses START -> match (bots fill 3v3)

signal state_changed(state: Dictionary)
signal kicked(reason: String)

var players := {}      # peer id -> {name, team, hero, ready}
var host_id := 1
var fill_bots := true
var in_match := false
var state := {}        # last received state (clients) / built state (server)


## Server side: open a room. with_local_player=false for dedicated servers.
func open_room(with_local_player := true) -> void:
	players.clear()
	in_match = false
	host_id = 1 if with_local_player else 0
	if with_local_player:
		players[1] = {"name": Settings.player_name, "team": 0, "hero": String(Settings.hero), "ready": true, "skin": Settings.skin_for(Settings.hero)}
	if not Net.peer_joined.is_connected(_on_peer_joined):
		Net.peer_joined.connect(_on_peer_joined)
		Net.peer_left.connect(_on_peer_left)
	_broadcast()


func close_room() -> void:
	players.clear()
	state = {}
	in_match = false


func _on_peer_joined(_id: int) -> void:
	pass   # the client introduces itself with req_join (needs its name / hero first)


func _on_peer_left(id: int) -> void:
	if not Net.is_server():
		return
	players.erase(id)
	if id == host_id:
		host_id = players.keys().min() if players.size() > 0 else 0   # host migration on dedicated servers
	if in_match and GameManager.match_node:
		var h: Hero = GameManager.match_node.heroes.get(id)
		if h:
			# a bot takes over the leaver's hero so the match stays 3v3
			h.is_bot = true
			h.player_name = "BOT " + h.player_name
			GameManager.match_node.bots[id] = BotBrain.new(GameManager.match_node, h)
	_broadcast()


func team_count(t: int) -> int:
	var n := 0
	for p in players.values():
		if p.team == t:
			n += 1
	return n


func _build_state() -> Dictionary:
	var list := []
	for id in players:
		var p: Dictionary = players[id]
		list.append({"id": id, "name": p.name, "team": p.team, "hero": p.hero, "skin": p.get("skin", 0), "ready": p.ready or id == host_id})
	return {"code": Net.room_code, "host": host_id, "players": list, "bots": fill_bots, "in_match": in_match}


func _broadcast() -> void:
	if not Net.is_server():
		return
	state = _build_state()
	state_changed.emit(state)
	if Net.is_online():
		rpc_state.rpc(state)


# ------------------------------------------------------------------ client -> server requests
func request_join() -> void:
	req_join.rpc_id(1, Settings.player_name, String(Settings.hero), Settings.skin_for(Settings.hero))


func set_hero(hero: StringName) -> void:
	Settings.hero = hero
	Settings.save()
	if Net.is_server():
		_apply(Net.my_id(), "hero", String(hero))
		_apply(Net.my_id(), "skin", Settings.skin_for(hero))
	else:
		req_set.rpc_id(1, "hero", String(hero))
		req_set.rpc_id(1, "skin", Settings.skin_for(hero))


func set_team(team: int) -> void:
	if Net.is_server():
		_apply(Net.my_id(), "team", team)
	else:
		req_set.rpc_id(1, "team", team)


func set_ready(ready: bool) -> void:
	if Net.is_server():
		_apply(Net.my_id(), "ready", ready)
	else:
		req_set.rpc_id(1, "ready", ready)


func set_fill_bots(on: bool) -> void:
	if Net.is_server():
		fill_bots = on
		_broadcast()
	else:
		req_set.rpc_id(1, "bots", on)


func start() -> void:
	if Net.is_server():
		_try_start(Net.my_id())
	else:
		req_start.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func req_join(p_name: String, hero: String, skin := 0) -> void:
	if not Net.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if in_match or players.size() >= 6:
		rpc_kicked.rpc_id(id, "Match already running" if in_match else "Room is full")
		return
	var team := 0 if team_count(0) <= team_count(1) else 1
	if not hero in ["volt", "brute", "nyx"]:
		hero = "volt"
	players[id] = {"name": p_name.substr(0, 14).strip_edges() if p_name.strip_edges() != "" else "Pilot", "team": team, "hero": hero, "ready": false, "skin": clampi(skin, 0, 2)}
	if host_id == 0:
		host_id = id
	_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_set(key: String, value: Variant) -> void:
	if Net.is_server():
		_apply(multiplayer.get_remote_sender_id(), key, value)


func _apply(id: int, key: String, value: Variant) -> void:
	if in_match or not players.has(id):
		return
	var p: Dictionary = players[id]
	match key:
		"hero":
			if String(value) in ["volt", "brute", "nyx"]:
				p.hero = String(value)
		"skin":
			p.skin = clampi(int(value), 0, 2)
		"team":
			var t := int(value)
			if (t == 0 or t == 1) and t != p.team and team_count(t) < 3:
				p.team = t
				p.ready = false
		"ready":
			p.ready = bool(value)
		"bots":
			if id == host_id:
				fill_bots = bool(value)
	_broadcast()


@rpc("any_peer", "call_remote", "reliable")
func req_start() -> void:
	if Net.is_server():
		_try_start(multiplayer.get_remote_sender_id())


func _try_start(by: int) -> void:
	if by != host_id or in_match:
		return
	for id in players:
		if id != host_id and not players[id].ready:
			return
	if players.size() < 2 and not fill_bots:
		return
	var roster := []
	for id in players:
		var p: Dictionary = players[id]
		roster.append({"id": id, "name": p.name, "team": p.team, "hero": p.hero, "peer": id, "skin": p.get("skin", 0)})
	if fill_bots:
		roster.append_array(GameManager.make_bots(roster))
	in_match = true
	_broadcast()
	rpc_start_match.rpc(roster)
	_start_local(roster)


@rpc("authority", "call_remote", "reliable")
func rpc_start_match(roster: Array) -> void:
	_start_local(roster)


func _start_local(roster: Array) -> void:
	var my := Net.my_id()
	if Net.dedicated:
		my = 0   # no local hero: the server only simulates
	GameManager.start_match(roster, my)


## Server: called by GameManager when a networked match ends -> back to the room.
func match_over() -> void:
	in_match = false
	for id in players:
		players[id].ready = id == host_id
	_broadcast()


@rpc("authority", "call_remote", "reliable")
func rpc_state(s: Dictionary) -> void:
	state = s
	in_match = s.in_match
	state_changed.emit(s)


@rpc("authority", "call_remote", "reliable")
func rpc_kicked(reason: String) -> void:
	kicked.emit(reason)
	Net.close()
