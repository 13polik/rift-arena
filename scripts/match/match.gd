class_name Match
extends Node3D
## One RIFT CORE match. Runs on every peer at the same node path (/root/Main/Match) so RPCs line up.
## SERVER (host / dedicated / offline): simulates everything at the physics rate, streams snapshots + events.
## CLIENT: sends inputs, predicts its own hero, renders everything through MatchView.

enum Phase { COUNTDOWN, PLAYING, ENDED }

signal finished(result: Dictionary)

const SNAPSHOT_HZ := 20.0
const HERO_SCENE := preload("res://characters/hero.tscn")

var mode_data: ModeData
var map: ArenaMap
var heroes := {}                 # id -> Hero
var combat: Combat
var abilities: AbilityRunner
var projectiles: ProjectileSystem
var zones: ZoneSystem
var mode: RiftCoreMode
var view: MatchView
var bots := {}                   # hero id -> BotBrain (server only)

var time := 0.0
var phase := Phase.COUNTDOWN
var play_start := 3.0
var local_id := 1
var is_server := true
var result := {}
var _events: Array = []
var _snap_acc := 0.0
var _full_sync_acc := 0.0
var _peer_team := {}             # peer id -> team (server)


## roster: [{id, name, team, hero, bot}]
func start(roster: Array, my_id: int, mode_override: ModeData = null) -> void:
	name = "Match"
	is_server = Net.is_server()
	local_id = my_id
	mode_data = mode_override if mode_override else load("res://resources/modes/rift_core.tres")
	play_start = mode_data.countdown
	var env := WorldEnvironment.new()
	env.environment = (load("res://resources/environment/arena_env.tres") as Environment).duplicate()
	env.environment.glow_enabled = Settings.glow_enabled()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -32, 0)
	sun.light_color = Color("fff1d6")
	sun.light_energy = 1.15
	sun.shadow_enabled = Settings.shadows_enabled()
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	map = ArenaMap.new()
	map.name = "Map"
	add_child(map)
	combat = Combat.new(self)
	abilities = AbilityRunner.new(self)
	projectiles = ProjectileSystem.new(self)
	zones = ZoneSystem.new(self)
	mode = RiftCoreMode.new(self)
	var heroes_root := Node3D.new()
	heroes_root.name = "Heroes"
	add_child(heroes_root)
	var used := [0, 0]
	for r in roster:
		var h: Hero = HERO_SCENE.instantiate()
		var hd := Skins.apply(Settings.hero_data(StringName(r.hero)), StringName(r.hero), int(r.get("skin", 0)))
		h.setup(r.id, r.name, r.team, hd, r.get("bot", false))
		var spawns := map.spawn_points(r.team)
		h.spawn_point = spawns[used[r.team] % spawns.size()]
		used[r.team] += 1
		h.position = h.spawn_point
		heroes_root.add_child(h)
		heroes[h.id] = h
		if r.has("peer"):
			_peer_team[r.peer] = r.team
		if is_server and r.get("bot", false):
			var brain := BotBrain.new(self, h)
			bots[h.id] = brain
	# A headless dedicated server only simulates: no models, animations, VFX or HUD (saves most of the CPU).
	if not Net.dedicated:
		view = MatchView.new()
		view.name = "View"
		add_child(view)
		view.setup(self)


func local_hero() -> Hero:
	return heroes.get(local_id)


func field_has_shards() -> bool:
	return view != null and view.field != null and view.field._shards.size() > 0


func space() -> PhysicsDirectSpaceState3D:
	return get_world_3d().direct_space_state


func event(e: Dictionary) -> void:
	_events.append(e)


# ======================================================================= SERVER
func _physics_process(delta: float) -> void:
	Prof.begin("server")
	if is_server:
		_server_tick(delta)
	else:
		time += delta
	Prof.end("server")
	if view:
		view.physics_tick(delta)


func _server_tick(dt: float) -> void:
	if phase == Phase.ENDED:
		return
	time += dt
	if phase == Phase.COUNTDOWN and time >= play_start:
		phase = Phase.PLAYING
		event({"t": "go"})
	var playing := phase == Phase.PLAYING
	for brain: BotBrain in bots.values():
		brain.think(dt)
	for h: Hero in heroes.values():
		h.cd[&"attack"] = maxf(0.0, h.cd[&"attack"] - dt)
		h.cd[&"ability"] = maxf(0.0, h.cd[&"ability"] - dt)
		if time >= h.slow_until:
			h.slow_factor = 1.0
		if not h.alive:
			h.in_actions.clear()
			continue
		if playing:
			for a in h.in_actions:
				abilities.use(h, a.slot, a.dir, a.mag)
			if h.in_fire:
				abilities.use(h, &"attack", h.in_aim)
			abilities.update(h)
			h.super_charge = minf(1.0, h.super_charge + h.data.super_passive_per_sec * dt)
		h.in_actions.clear()
		var frozen := not playing or _has_pending(h, &"slam")
		h.step_move(Vector3.ZERO if frozen else h.in_move, dt)
		if h.in_fire and h.in_aim.length_squared() > 0.01:
			h.facing = h.in_aim
		Health.regen(h, dt, time)
		h.bush = map.bush_index_at(h.position)
	if playing:
		projectiles.update(dt)
		zones.update()
		combat.update_respawns()
		mode.update(dt)
	_flush_events()
	_snap_acc += dt
	if _snap_acc >= 1.0 / SNAPSHOT_HZ:
		_snap_acc = 0.0
		_send_snapshots()


func _has_pending(h: Hero, kind: StringName) -> bool:
	for p in h.pending:
		if p.kind == kind:
			return true
	return false


## Bushes hide you from the other team unless revealed (attacked recently, hurt, carrying lots, or enemy close).
func visible_to(target: Hero, team: int) -> bool:
	if target.team == team or not target.alive:
		return true
	if not is_server:
		return target.get_meta(&"seen", true)
	if target.bush < 0:
		return true
	if time - target.last_attack_at < mode_data.reveal_after_attack or time - target.last_damaged_at < mode_data.reveal_after_damage:
		return true
	if target.carried >= mode_data.reveal_carry:
		return true
	var r2 := mode_data.bush_reveal_distance * mode_data.bush_reveal_distance
	for o: Hero in heroes.values():
		if o.team == team and o.alive and Vector2(o.position.x - target.position.x, o.position.z - target.position.z).length_squared() <= r2:
			return true
	return false


func _flush_events() -> void:
	if _events.is_empty():
		return
	var evs := _events
	_events = []
	if view:
		view.on_events(evs)
	if Net.is_online():
		rpc_events.rpc(evs)


func _send_snapshots() -> void:
	if not Net.is_online():
		return
	for peer in multiplayer.get_peers():
		var team: int = _peer_team.get(peer, 0)
		rpc_snapshot.rpc_id(peer, _build_snapshot(team, peer))


func _build_snapshot(team: int, peer: int) -> Array:
	var hs := []
	for h: Hero in heroes.values():
		if not visible_to(h, team):
			continue
		hs.append([h.id, snappedf(h.position.x, 0.01), snappedf(h.position.z, 0.01), snappedf(h.facing.x, 0.01), snappedf(h.facing.z, 0.01),
			int(h.hp), h.flags(time), h.carried])
	var me := []
	var mine: Hero = heroes.get(peer)
	if mine:
		me = [mine.input_seq, snappedf(mine.cd[&"ability"], 0.01), snappedf(mine.super_charge, 0.01),
			snappedf(maxf(0.0, mine.respawn_at - time), 0.1), snappedf(mine.slow_factor, 0.01)]
	_full_sync_acc += 1.0
	var shards := []
	if int(_full_sync_acc) % 20 == 0:
		shards = mode.shard_list()
	return [time, phase, mode.score[0], mode.score[1], mode.time_left(), mode.pulse_in(), hs, projectiles.homing_states(), me, shards, zones.snapshot()]


func end_match(winner: int, reason: String) -> void:
	if phase == Phase.ENDED:
		return
	phase = Phase.ENDED
	var players := []
	for h: Hero in heroes.values():
		players.append({"id": h.id, "name": h.player_name, "team": h.team, "hero": String(h.data.id), "bot": h.is_bot,
			"kills": h.stats.kills, "deaths": h.stats.deaths, "delivered": h.stats.delivered,
			"damage": int(h.stats.damage), "healing": int(h.stats.healing)})
	result = {"winner": winner, "reason": reason, "score": mode.score.duplicate(), "players": players}
	_flush_events()
	if Net.is_online():
		rpc_end.rpc(result)
	_on_end(result)


func _on_end(res: Dictionary) -> void:
	phase = Phase.ENDED
	result = res
	if view:
		view.on_match_end(res)
	get_tree().create_timer(3.2).timeout.connect(func(): finished.emit(res))


# ======================================================================= NETWORK (RPC)
## Client -> server: movement / aim / fire for this physics tick.
@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func rpc_input(seq: int, mx: float, mz: float, ax: float, az: float, fire: bool) -> void:
	if not is_server:
		return
	var h: Hero = heroes.get(multiplayer.get_remote_sender_id())
	if h == null or seq <= h.input_seq:
		return
	h.input_seq = seq
	h.in_move = Vector3(clampf(mx, -1, 1), 0, clampf(mz, -1, 1)).limit_length(1.0)
	var a := Vector3(ax, 0, az)
	if a.length_squared() > 0.01:
		h.in_aim = a.normalized()
	h.in_fire = fire


## Client -> server: ability / super / manual shot (reliable so taps are never lost).
@rpc("any_peer", "call_remote", "reliable", 2)
func rpc_action(slot: String, dx: float, dz: float, mag: float) -> void:
	if not is_server or not slot in ["attack", "ability", "super"]:
		return
	var h: Hero = heroes.get(multiplayer.get_remote_sender_id())
	if h and h.in_actions.size() < 4:
		h.in_actions.append({"slot": StringName(slot), "dir": Vector3(dx, 0, dz), "mag": clampf(mag, 0.0, 1.0)})


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func rpc_snapshot(s: Array) -> void:
	if view:
		view.on_snapshot(s)


@rpc("authority", "call_remote", "reliable", 2)
func rpc_events(evs: Array) -> void:
	if view:
		view.on_events(evs)


@rpc("authority", "call_remote", "reliable", 2)
func rpc_end(res: Dictionary) -> void:
	_on_end(res)
