class_name ZoneSystem
extends RefCounted
## Server-side ground zones: STASIS (slow + damage to enemies) and BLOOM (heal allies). Effects pulse every 0.5 s.

const PULSE := 0.5

var m: Match
var zones: Array[Dictionary] = []
var _next_id := 1


func _init(match_node: Match) -> void:
	m = match_node


func spawn(owner: Hero, def: AbilityData, pos: Vector3) -> void:
	var z := {"id": _next_id, "owner": owner, "team": owner.team, "pos": Vector3(pos.x, 0, pos.z), "r": def.zone_radius,
		"effect": def.zone_effect, "mag": def.magnitude, "dps": def.dps, "end": m.time + def.duration, "next": m.time}
	_next_id += 1
	zones.append(z)
	m.event({"t": "zs", "id": z.id, "x": pos.x, "z": pos.z, "r": z.r, "e": String(z.effect), "tm": z.team, "d": def.duration})


func update() -> void:
	var i := 0
	while i < zones.size():
		var z: Dictionary = zones[i]
		if m.time >= z.end:
			m.event({"t": "ze", "id": z.id})
			zones.remove_at(i)
			continue
		var pulse: bool = m.time >= z.next
		if pulse:
			z.next += PULSE
		if z.effect == &"slow":
			for e in m.combat.enemies_in_radius(z.team, z.pos, z.r):
				e.slow_until = maxf(e.slow_until, m.time + 0.15)
				e.slow_factor = minf(e.slow_factor, 1.0 - z.mag)
				if pulse and z.dps > 0.0:
					m.combat.damage(z.owner, e, z.dps * PULSE)
		elif z.effect == &"heal" and pulse:
			for a in m.combat.allies_in_radius(z.team, z.pos, z.r):
				m.combat.heal(z.owner, a, z.mag * PULSE)
		i += 1


func snapshot() -> Array:
	var out := []
	for z in zones:
		out.append([z.id, z.pos.x, z.pos.z, z.r, String(z.effect), z.team, z.end - m.time])
	return out
