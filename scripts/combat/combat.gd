class_name Combat
extends RefCounted
## Server-side combat rules: damage routing (knockback, super charge, stats, events), eliminations, respawns.

var m: Match


func _init(match_node: Match) -> void:
	m = match_node


func enemies_in_radius(team: int, pos: Vector3, r: float) -> Array[Hero]:
	var out: Array[Hero] = []
	for h in m.heroes.values():
		if h.team != team and h.alive:
			var rr: float = r + h.data.radius
			if Vector2(h.position.x - pos.x, h.position.z - pos.z).length_squared() <= rr * rr:
				out.append(h)
	return out


func allies_in_radius(team: int, pos: Vector3, r: float) -> Array[Hero]:
	var out: Array[Hero] = []
	for h in m.heroes.values():
		if h.team == team and h.alive and Vector2(h.position.x - pos.x, h.position.z - pos.z).length_squared() <= r * r:
			out.append(h)
	return out


## Returns damage actually dealt. kb is a knockback strength (meters, roughly).
func damage(src: Hero, target: Hero, amount: float, kb_dir := Vector3.ZERO, kb := 0.0, heavy := false) -> float:
	var dealt := Health.apply_damage(target, amount, m.time)
	if dealt <= 0.0:
		return 0.0
	if kb > 0.0 and kb_dir.length_squared() > 0.0001:
		kb_dir.y = 0.0
		target.knockback += kb_dir.normalized() * sqrt(2.0 * 18.0 * kb)   # v such that it slides ~kb meters
	if src and src != target:
		src.stats.damage += dealt
		var need: float = src.data.super_ability.charge_required
		if need > 0.0:
			src.super_charge = minf(1.0, src.super_charge + dealt / need)
	m.event({"t": "hit", "v": target.id, "a": int(dealt), "h": heavy, "s": src.id if src else 0})
	if target.hp <= 0.0:
		eliminate(src, target)
	return dealt


func heal(src: Hero, target: Hero, amount: float) -> float:
	var healed := Health.apply_heal(target, amount)
	if healed > 0.0:
		if src:
			src.stats.healing += healed
		m.event({"t": "heal", "v": target.id, "a": int(healed)})
	return healed


func eliminate(killer: Hero, victim: Hero) -> void:
	victim.alive = false
	victim.hp = 0.0
	victim.dash = {}
	victim.pending.clear()
	victim.knockback = Vector3.ZERO
	victim.respawn_at = m.time + m.mode_data.respawn_time
	victim.stats.deaths += 1
	if killer and killer != victim:
		killer.stats.kills += 1
		# eliminations refund a chunk of super - rewards aggression
		killer.super_charge = minf(1.0, killer.super_charge + 0.15)
	m.event({"t": "kill", "k": killer.id if killer else 0, "v": victim.id, "x": victim.position.x, "z": victim.position.z})
	m.mode.on_death(victim)


func update_respawns() -> void:
	for h: Hero in m.heroes.values():
		if h.alive or m.time < h.respawn_at:
			continue
		h.alive = true
		h.hp = h.data.max_hp
		h.position = h.spawn_point
		h.velocity = Vector3.ZERO
		h.knockback = Vector3.ZERO
		h.invuln_until = m.time + m.mode_data.spawn_protection
		h.last_damaged_at = -99.0
		h.slow_until = 0.0
		h.slow_factor = 1.0
		h.facing = Vector3(1, 0, 0) if h.team == 0 else Vector3(-1, 0, 0)
		m.event({"t": "spawn", "p": h.id, "x": h.position.x, "z": h.position.z})
