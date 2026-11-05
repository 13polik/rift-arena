class_name BotBrain
extends RefCounted
## Server-side bot. Writes the same inputs a human would (move / aim / fire / actions) into its Hero,
## so bots obey every game rule. Navigation uses the baked NavigationServer3D map.
##
## Priorities (re-evaluated ~4x per second):
##   1. deliver energy when carrying enough (or any when threatened / match ending)
##   2. retreat to base when badly hurt
##   3. fight visible enemies in range, keeping a hero-specific distance and strafing
##   4. escort a teammate that carries a lot of energy
##   5. collect shards (skips shards a teammate is already closer to)
##   6. hold the middle and wait for the next core pulse

var m: Match
var h: Hero
var _think := 0.0
var _goal := Vector3.ZERO
var _goal_kind := &"mid"
var _path := PackedVector3Array()
var _path_i := 0
var _repath := 0.0
var _enemy: Hero
var _seen_since := {}
var _strafe := 1.0
var _strafe_t := 0.0
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _sidestep := Vector3.ZERO
var _sidestep_t := 0.0
var _reaction := randf_range(0.18, 0.32)
var _aim_error := randf_range(0.05, 0.14)
var _mid_offset := Vector3(randf_range(-2.5, 2.5), 0, randf_range(-3.5, 3.5))


func _init(match_node: Match, hero: Hero) -> void:
	m = match_node
	h = hero


func _pref_range() -> float:
	match h.data.attack.kind:
		AbilityData.Kind.MELEE: return 1.4
	return h.data.attack.range * 0.68


func think(dt: float) -> void:
	h.in_fire = false
	if not h.alive or m.phase != Match.Phase.PLAYING:
		h.in_move = Vector3.ZERO
		_path = PackedVector3Array()
		return
	_think -= dt
	if _think <= 0.0:
		_think = randf_range(0.2, 0.3)
		_decide()
	_combat(dt)
	_steer(dt)


# ------------------------------------------------------------------ decisions
func _decide() -> void:
	var cfg := m.mode_data
	_enemy = _pick_enemy(13.0)
	var hp := h.hp_frac()
	var home := m.map.uplink_pos(h.team)
	var threatened := _enemy != null and _dist(_enemy) < 7.0
	var ending := m.mode.time_left() < 25.0
	if h.carried >= cfg.max_carry or h.carried >= 4 or (h.carried > 0 and (threatened or ending or hp < 0.5)) or (h.carried >= 2 and m.mode.shards.size() == 0):
		_set_goal(home, &"deliver")
	elif hp < 0.3 and _enemy != null:
		_set_goal(m.map.spawn_points(h.team)[1], &"retreat")
	elif _enemy != null and (_dist(_enemy) < h.data.attack.range + 3.0 or _enemy.carried >= 3):
		_set_goal(_fight_position(_enemy), &"fight")
	else:
		var carrier := _ally_carrier()
		var shard := _pick_shard()
		if carrier and (shard.is_empty() or _dist(carrier) < 6.0):
			_set_goal(carrier.position + (m.map.uplink_pos(h.team) - carrier.position).normalized() * -2.0, &"escort")
		elif not shard.is_empty():
			_set_goal(shard.pos, &"shard")
		else:
			_set_goal(Vector3(-3.0 if h.team == 0 else 3.0, 0, 0) + _mid_offset, &"mid")


func _pick_enemy(rng: float) -> Hero:
	var best: Hero = null
	var best_score := INF
	var now := m.time
	for e: Hero in m.heroes.values():
		if e.team == h.team or not e.alive or not m.visible_to(e, h.team):
			_seen_since.erase(e.id)
			continue
		var d := _dist(e)
		if d > rng:
			_seen_since.erase(e.id)
			continue
		if not _seen_since.has(e.id):
			_seen_since[e.id] = now
		var score := d - e.carried * 1.5 - (1.0 - e.hp_frac()) * 3.0
		if score < best_score:
			best_score = score
			best = e
	return best


func _ally_carrier() -> Hero:
	for a: Hero in m.heroes.values():
		if a != h and a.team == h.team and a.alive and a.carried >= 3 and _dist(a) < 12.0:
			return a
	return null


func _pick_shard() -> Dictionary:
	var best := {}
	var bd := INF
	for s in m.mode.shards:
		var d := Vector2(s.pos.x - h.position.x, s.pos.z - h.position.z).length()
		var taken := false
		for a: Hero in m.heroes.values():
			if a != h and a.team == h.team and a.alive and Vector2(s.pos.x - a.position.x, s.pos.z - a.position.z).length() < d - 0.5:
				taken = true
				break
		if not taken and d < bd:
			bd = d
			best = s
	return best


func _fight_position(e: Hero) -> Vector3:
	var to := h.position - e.position
	to.y = 0.0
	var d := to.length()
	var pref := _pref_range()
	var dir := to.normalized() if d > 0.01 else Vector3.RIGHT
	var target := e.position + dir * pref
	# strafe around the target so bots don't stand still
	target += dir.cross(Vector3.UP) * _strafe * 1.5
	return target


func _set_goal(p: Vector3, kind: StringName) -> void:
	if kind != _goal_kind or p.distance_to(_goal) > 1.2:
		_goal = p
		_goal_kind = kind
		_repath = 0.0


func _dist(o: Hero) -> float:
	return Vector2(o.position.x - h.position.x, o.position.z - h.position.z).length()


# ------------------------------------------------------------------ movement
func _steer(dt: float) -> void:
	_repath -= dt
	if _repath <= 0.0 or _path_i >= _path.size():
		_repath = 0.5
		var nav := m.map.nav_region.get_navigation_map()
		_path = NavigationServer3D.map_get_path(nav, h.position, _goal, true)
		_path_i = 0
	var target := _goal
	while _path_i < _path.size():
		var wp := _path[_path_i]
		if Vector2(wp.x - h.position.x, wp.z - h.position.z).length() < 0.45:
			_path_i += 1
		else:
			target = wp
			break
	var to := Vector3(target.x - h.position.x, 0, target.z - h.position.z)
	var arrive := to.length() < 0.3 and _path_i >= _path.size()
	var move := Vector3.ZERO if arrive else to.normalized()
	if _goal_kind == &"fight":
		_strafe_t -= dt
		if _strafe_t <= 0.0:
			_strafe_t = randf_range(0.7, 1.6)
			_strafe = -_strafe
	# stuck detection: sidestep briefly
	if h.position.distance_to(_last_pos) < 0.02 and move != Vector3.ZERO:
		_stuck_t += dt
	else:
		_stuck_t = 0.0
	_last_pos = h.position
	if _stuck_t > 0.4:
		_stuck_t = 0.0
		_sidestep = move.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
		_sidestep_t = 0.35
		_repath = 0.0
	if _sidestep_t > 0.0:
		_sidestep_t -= dt
		move = (move * 0.3 + _sidestep).normalized()
	h.in_move = move


# ------------------------------------------------------------------ combat
func _combat(dt: float) -> void:
	var e := _enemy
	if e == null or not e.alive or not m.visible_to(e, h.team):
		_maybe_support()
		return
	if m.time - float(_seen_since.get(e.id, m.time)) < _reaction:
		return
	var d := _dist(e)
	var atk := h.data.attack
	# lead the target a little, with human-like error
	var travel := d / maxf(atk.projectile_speed, 1.0) if atk.kind != AbilityData.Kind.MELEE else 0.0
	var aim_pt := e.position + e.velocity * travel * 0.7
	var aim := (aim_pt - h.position)
	aim.y = 0.0
	aim = aim.normalized().rotated(Vector3.UP, randf_range(-_aim_error, _aim_error))
	h.in_aim = aim
	if d <= atk.range + 0.3:
		h.in_fire = true
	_use_ability(e, d)
	_use_super(e, d)


func _queue(slot: StringName, dir: Vector3, mag := 1.0) -> void:
	h.in_actions.append({"slot": slot, "dir": dir, "mag": mag})


func _use_ability(e: Hero, d: float) -> void:
	if h.cd[&"ability"] > 0.0:
		return
	var to := (e.position - h.position).normalized()
	match h.data.ability.kind:
		AbilityData.Kind.BLINK:
			if h.hp_frac() < 0.45 and d < 4.0:
				_queue(&"ability", -to)                      # escape
			elif e.carried >= 2 and d > 5.0 and d < 9.0:
				_queue(&"ability", to)                       # chase a carrier
		AbilityData.Kind.CHARGE:
			if d > 2.5 and d < h.data.ability.range:
				_queue(&"ability", to)
		AbilityData.Kind.ZONE:
			var cr := h.data.ability.cast_range
			if d < cr + 1.0 and h.data.ability.zone_effect == &"slow":
				_queue(&"ability", to, clampf(d / cr, 0.0, 1.0))


func _use_super(e: Hero, d: float) -> void:
	if h.super_charge < 1.0:
		return
	var sup := h.data.super_ability
	var to := (e.position - h.position).normalized()
	match sup.kind:
		AbilityData.Kind.BLAST_PROJECTILE:
			if d > 3.0 and d < sup.range:
				_queue(&"super", to)
		AbilityData.Kind.SHOCKWAVE:
			if m.combat.enemies_in_radius(h.team, h.position, sup.range * 0.8).size() >= 1:
				_queue(&"super", to)
		AbilityData.Kind.ZONE:
			_maybe_support()


## Nyx: drop the healing bloom on hurt allies (or herself).
func _maybe_support() -> void:
	var sup := h.data.super_ability
	if h.super_charge < 1.0 or sup.kind != AbilityData.Kind.ZONE or sup.zone_effect != &"heal":
		return
	for a: Hero in m.heroes.values():
		if a.team == h.team and a.alive and a.hp_frac() < 0.6 and _dist(a) < sup.cast_range + 1.0:
			var to := a.position - h.position
			_queue(&"super", to.normalized() if to.length() > 0.1 else h.facing, clampf(to.length() / sup.cast_range, 0.0, 1.0))
			return
