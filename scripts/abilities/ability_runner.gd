class_name AbilityRunner
extends RefCounted
## Executes attacks / abilities / supers on the server. Behaviour is chosen by AbilityData.kind and all numbers
## come from the hero's .tres resource, so new heroes can reuse kinds without new code.

const K := AbilityData.Kind
var m: Match


func _init(match_node: Match) -> void:
	m = match_node


## slot: &"attack" | &"ability" | &"super". dir: world direction. mag: 0..1 (placement distance for zones).
func use(h: Hero, slot: StringName, dir: Vector3, mag := 1.0) -> bool:
	if not h.alive or h.dash.size() > 0 or m.phase != Match.Phase.PLAYING:
		return false
	var def := h.data.slot(slot)
	if slot == &"super":
		if h.super_charge < 1.0:
			return false
	elif h.cd[slot] > 0.0:
		return false
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = h.facing
	dir = dir.normalized()
	h.facing = dir
	match def.kind:
		K.PROJECTILE, K.BLAST_PROJECTILE:
			for i in def.burst_count:
				h.pending.append({"at": m.time + i * def.burst_interval, "kind": &"volley", "def": def, "dir": dir})
		K.MELEE:
			h.pending.append({"at": m.time + def.windup, "kind": &"melee", "def": def, "dir": dir})
		K.BLINK:
			_blink(h, def, dir)
		K.CHARGE:
			h.dash = {"vel": dir * (def.range / def.duration), "until": m.time + def.duration, "hit": {}, "def": def}
		K.ZONE:
			_zone(h, def, dir, mag)
		K.SHOCKWAVE:
			h.pending.append({"at": m.time + def.windup, "kind": &"slam", "def": def})
	if slot == &"super":
		h.super_charge = 0.0
	else:
		h.cd[slot] = def.cooldown
	h.last_attack_at = m.time
	h.invuln_until = minf(h.invuln_until, m.time)   # acting cancels spawn protection
	m.event({"t": "cast", "p": h.id, "s": slot, "x": h.position.x, "z": h.position.z, "dx": dir.x, "dz": dir.z})
	return true


## Per-tick: dashes and scheduled effects (burst volleys, melee windups, slams).
func update(h: Hero) -> void:
	if h.dash.size() > 0:
		_update_dash(h)
	if h.pending.is_empty():
		return
	var i := 0
	while i < h.pending.size():
		var p: Dictionary = h.pending[i]
		if m.time >= p.at:
			h.pending.remove_at(i)
			match p.kind:
				&"volley": _volley(h, p.def, p.dir)
				&"melee": _melee(h, p.def, p.dir)
				&"slam": _slam(h, p.def)
		else:
			i += 1


func _volley(h: Hero, def: AbilityData, dir: Vector3) -> void:
	var base := atan2(dir.z, dir.x)
	for i in def.count:
		var a := base
		if def.count > 1:
			a += (float(i) / (def.count - 1) - 0.5) * deg_to_rad(def.spread_deg)
		var d := Vector3(cos(a), 0, sin(a))
		m.projectiles.spawn(h, def, h.position + d * (h.data.radius + 0.1), d)


func _melee(h: Hero, def: AbilityData, dir: Vector3) -> void:
	var half := deg_to_rad(def.arc_deg) * 0.5
	for e in m.combat.enemies_in_radius(h.team, h.position, def.range):
		var to := e.position - h.position
		to.y = 0.0
		var close := to.length() < e.data.radius + h.data.radius + 0.25
		if close or absf(dir.signed_angle_to(to.normalized(), Vector3.UP)) <= half:
			m.combat.damage(h, e, def.damage, to if to.length() > 0.1 else dir, def.knockback, true)


func _blink(h: Hero, def: AbilityData, dir: Vector3) -> void:
	var from := h.position
	var target := from + dir * def.range
	var q := PhysicsRayQueryParameters3D.create(from + Vector3(0, 0.8, 0), target + Vector3(0, 0.8, 0), Hero.WORLD_MASK)
	var hit := m.space().intersect_ray(q)
	if hit:
		target = Vector3(hit.position.x, 0, hit.position.z) - dir * (h.data.radius + 0.15)
	# never end inside geometry: walk back until the spot is free
	var tries := 0
	while m.map.is_solid(target.x, target.z) and tries < 20:
		target -= dir * 0.2
		tries += 1
	h.position = Vector3(target.x, 0, target.z)
	h.knockback = Vector3.ZERO
	m.event({"t": "fx", "f": "blink", "p": h.id, "x": from.x, "z": from.z, "x2": h.position.x, "z2": h.position.z})


func _update_dash(h: Hero) -> void:
	var d := h.dash
	for e in m.combat.enemies_in_radius(h.team, h.position, h.data.radius + 0.35):
		if d.hit.has(e.id):
			continue
		d.hit[e.id] = true
		m.combat.damage(h, e, d.def.damage, d.vel, d.def.knockback, true)
	# stop early when blocked by a wall
	if m.time >= d.until or (h.get_slide_collision_count() > 0 and h.get_real_velocity().length() < d.vel.length() * 0.35):
		h.dash = {}
		m.event({"t": "fx", "f": "dash_end", "p": h.id, "x": h.position.x, "z": h.position.z})


func _slam(h: Hero, def: AbilityData) -> void:
	for e in m.combat.enemies_in_radius(h.team, h.position, def.range):
		var out := e.position - h.position
		m.combat.damage(h, e, def.damage, out if out.length() > 0.1 else h.facing, def.knockback, true)
		e.slow_until = m.time + def.slow_duration
		e.slow_factor = def.slow_factor
	m.event({"t": "fx", "f": "quake", "p": h.id, "x": h.position.x, "z": h.position.z, "r": def.range})


func _zone(h: Hero, def: AbilityData, dir: Vector3, mag: float) -> void:
	var dist := clampf(mag, 0.0, 1.0) * def.cast_range
	var pos := h.position
	var d := dist
	while d >= 0.0:
		var p := h.position + dir * d
		if not m.map.is_solid(p.x, p.z):
			pos = p
			break
		d -= 0.5
	m.zones.spawn(h, def, pos)
