class_name RiftCoreMode
extends RefCounted
## RIFT CORE (server rules).
##  - The core pulses every pulse_interval s and scatters energy shards (more during the late "surge").
##  - Walk over shards to carry them (max_carry). Carrying >= reveal_carry makes you glow: bushes can't hide you.
##  - Stand in your team's Uplink to channel carried energy into score, one shard per deposit_interval.
##  - Dying drops everything you carry. Unclaimed shards fade after shard_lifetime.
##  - First team to win_score wins; on time-out the higher score wins (equal = draw).

var m: Match
var cfg: ModeData
var score := [0, 0]
var shards: Array[Dictionary] = []
var next_pulse := 0.0
var _next_id := 1


func _init(match_node: Match) -> void:
	m = match_node
	cfg = m.mode_data
	next_pulse = cfg.first_pulse_at


func elapsed() -> float:
	return m.time - m.play_start


func time_left() -> float:
	return maxf(0.0, cfg.duration - elapsed())


func _spawn_shard(origin: Vector3, rmin: float, rmax: float) -> void:
	if shards.size() >= cfg.max_shards_on_field:
		return
	for i in 12:
		var a := randf() * TAU
		var r := randf_range(rmin, rmax)
		var p := origin + Vector3(cos(a) * r, 0, sin(a) * r)
		if not m.map.is_solid(p.x, p.z):
			var s := {"id": _next_id, "pos": p, "born": m.time}
			_next_id += 1
			shards.append(s)
			m.event({"t": "ss", "id": s.id, "x": p.x, "z": p.z, "fx": origin.x, "fz": origin.z})
			return


func update(dt: float) -> void:
	# 1) core pulse
	if elapsed() >= next_pulse:
		next_pulse += cfg.pulse_interval
		var n := cfg.surge_shards_per_pulse if elapsed() >= cfg.surge_after else cfg.shards_per_pulse
		m.event({"t": "pulse", "surge": elapsed() >= cfg.surge_after})
		for i in n:
			_spawn_shard(Vector3.ZERO, cfg.shard_scatter_min, cfg.shard_scatter_max)
	# 2) fade old shards
	var i := 0
	while i < shards.size():
		if m.time - shards[i].born >= cfg.shard_lifetime:
			m.event({"t": "se", "id": shards[i].id})
			shards.remove_at(i)
		else:
			i += 1
	# 3) pickups + deposits
	for h: Hero in m.heroes.values():
		if not h.alive:
			continue
		var j := shards.size() - 1
		while j >= 0 and h.carried < cfg.max_carry:
			var s: Dictionary = shards[j]
			if Vector2(s.pos.x - h.position.x, s.pos.z - h.position.z).length() <= cfg.pickup_radius + h.data.radius * 0.5:
				shards.remove_at(j)
				h.carried += 1
				m.event({"t": "sp", "id": s.id, "p": h.id, "n": h.carried})
			j -= 1
		var up := m.map.uplink_pos(h.team)
		if h.carried > 0 and Vector2(h.position.x - up.x, h.position.z - up.z).length() <= FractureYardLayout.UPLINK_RADIUS:
			h.deposit_timer += dt
			while h.deposit_timer >= cfg.deposit_interval and h.carried > 0:
				h.deposit_timer -= cfg.deposit_interval
				h.carried -= 1
				h.stats.delivered += 1
				score[h.team] += 1
				m.event({"t": "dep", "p": h.id, "tm": h.team, "sc": score.duplicate()})
				if score[h.team] >= cfg.win_score:
					m.end_match(h.team, "score")
					return
		else:
			h.deposit_timer = 0.0
	# 4) time limit
	if time_left() <= 0.0:
		var winner := -1 if score[0] == score[1] else (0 if score[0] > score[1] else 1)
		m.end_match(winner, "time")


func on_death(h: Hero) -> void:
	for k in h.carried:
		_spawn_shard(h.position, 0.4, 1.7)
	h.carried = 0


func pulse_in() -> float:
	return maxf(0.0, next_pulse - elapsed())


## Full shard list (sent periodically so late/lossy clients converge).
func shard_list() -> Array:
	var out := []
	for s in shards:
		out.append([s.id, s.pos.x, s.pos.z])
	return out
