class_name ProjectileSystem
extends RefCounted
## Server-side projectile simulation with a fixed pool (no allocations while fighting).
## Walls are tested with physics raycasts, heroes with segment-vs-circle math (cheap, exact enough).

const POOL_SIZE := 160
const HEIGHT := 0.95


class Proj:
	var active := false
	var id := 0
	var owner: Hero
	var team := 0
	var pos := Vector3.ZERO
	var dir := Vector3.FORWARD
	var speed := 0.0
	var range := 0.0
	var radius := 0.2
	var damage := 0.0
	var traveled := 0.0
	var kind: StringName
	var homing := 0.0
	var acquire := 0.0
	var blast := 0.0
	var knockback := 0.0
	var shake := 0.0

var m: Match
var pool: Array[Proj] = []
var _next_id := 1


func _init(match_node: Match) -> void:
	m = match_node
	for i in POOL_SIZE:
		pool.append(Proj.new())


func spawn(owner: Hero, def: AbilityData, pos: Vector3, dir: Vector3) -> void:
	var p: Proj = null
	for o in pool:
		if not o.active:
			p = o
			break
	if p == null:
		return  # pool exhausted -> drop the shot instead of allocating
	p.active = true
	p.id = _next_id
	_next_id += 1
	p.owner = owner
	p.team = owner.team
	p.pos = Vector3(pos.x, 0, pos.z)
	p.dir = dir
	p.speed = def.projectile_speed
	p.range = def.range
	p.radius = def.projectile_radius
	p.damage = def.damage
	p.traveled = 0.0
	p.kind = def.vfx
	p.homing = def.homing_turn_rate
	p.acquire = def.homing_acquire_range
	p.blast = def.blast_radius
	p.knockback = def.knockback
	p.shake = def.shake
	m.event({"t": "ps", "id": p.id, "o": owner.id, "tm": p.team, "k": p.kind, "x": p.pos.x, "z": p.pos.z, "dx": dir.x, "dz": dir.z, "sp": p.speed, "r": p.range, "hm": p.homing > 0.0})


func update(dt: float) -> void:
	var space := m.space()
	for p in pool:
		if not p.active:
			continue
		if p.homing > 0.0:
			_steer(p, dt)
		var step := p.speed * dt
		var from := p.pos
		var to := p.pos + p.dir * step
		# heroes first (segment vs circle)
		var victim: Hero = null
		var best := INF
		for h: Hero in m.heroes.values():
			if h.team == p.team or not h.alive:
				continue
			var d := _seg_dist(from, to, h.position)
			if d <= p.radius + h.data.radius and d < best:
				best = d
				victim = h
		if victim:
			p.pos = victim.position
			_finish(p, victim)
			continue
		var q := PhysicsRayQueryParameters3D.create(from + Vector3(0, HEIGHT, 0), to + Vector3(0, HEIGHT, 0), Hero.WORLD_MASK)
		var hit := space.intersect_ray(q)
		if hit:
			p.pos = Vector3(hit.position.x, 0, hit.position.z) - p.dir * 0.05
			_finish(p, null)
			continue
		p.pos = to
		p.traveled += step
		if p.traveled >= p.range:
			_finish(p, null)


func _seg_dist(a: Vector3, b: Vector3, c: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ac := Vector2(c.x - a.x, c.z - a.z)
	var t := clampf(ac.dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return (ac - ab * t).length()


## Homing: turn toward the closest enemy this team can currently SEE (bushes still protect).
func _steer(p: Proj, dt: float) -> void:
	var target: Hero = null
	var bd := p.acquire * p.acquire
	for h: Hero in m.heroes.values():
		if h.team == p.team or not h.alive or not m.visible_to(h, p.team):
			continue
		var d := Vector2(h.position.x - p.pos.x, h.position.z - p.pos.z).length_squared()
		if d < bd:
			bd = d
			target = h
	if target == null:
		return
	var want := Vector3(target.position.x - p.pos.x, 0, target.position.z - p.pos.z).normalized()
	var ang := p.dir.signed_angle_to(want, Vector3.UP)
	var turn := clampf(ang, -p.homing * dt, p.homing * dt)
	p.dir = p.dir.rotated(Vector3.UP, turn)


func _finish(p: Proj, victim: Hero) -> void:
	p.active = false
	if p.blast > 0.0:
		for e in m.combat.enemies_in_radius(p.team, p.pos, p.blast):
			var out := e.position - p.pos
			m.combat.damage(p.owner, e, p.damage, out if out.length() > 0.1 else p.dir, p.knockback, true)
		m.event({"t": "pe", "id": p.id, "x": p.pos.x, "z": p.pos.z, "hit": true, "b": p.blast, "k": p.kind, "tm": p.team})
		return
	if victim:
		m.combat.damage(p.owner, victim, p.damage, p.dir, p.knockback, false)
	m.event({"t": "pe", "id": p.id, "x": p.pos.x, "z": p.pos.z, "hit": victim != null, "b": 0.0, "k": p.kind, "tm": p.team})


## Positions of homing projectiles for snapshots (straight ones are simulated identically on clients).
func homing_states() -> Array:
	var out := []
	for p in pool:
		if p.active and p.homing > 0.0:
			out.append([p.id, snappedf(p.pos.x, 0.01), snappedf(p.pos.z, 0.01), snappedf(p.dir.x, 0.01), snappedf(p.dir.z, 0.01)])
	return out
