class_name MatchView
extends Node
## Presentation side of a match (runs on every peer that has a screen):
##  - samples local input (PlayerInput) each tick: applies it directly on the server, sends RPCs on clients
##  - client prediction for the local hero + interpolation for everyone else
##  - turns server events into animations, VFX, SFX, camera shake, damage numbers, HUD messages

const INTERP_DELAY := 0.1

var m: Match
var camera: GameCamera
var vfx: VFX
var projectiles: ProjectileView
var field: FieldView
var hud: HUD
var touch: TouchControls
var input: PlayerInput
var aim_line: MeshInstance3D
var my_team := 0
var _seq := 0
var _snaps: Array = []           # client interpolation buffer: [{t, heroes: {id: arr}}]
var _clock_offset := 0.0
var _have_clock := false
var _last_snap: Array = []
var _me_info := []
var _was_alive := {}
var _was_bush := {}


func setup(match_node: Match) -> void:
	m = match_node
	var me := m.local_hero()
	my_team = me.team if me else 0
	for h: Hero in m.heroes.values():
		h.make_visual(h.id == m.local_id, h.team == my_team)
		h.visual.footstep.connect(_on_footstep.bind(h))
		_was_alive[h.id] = true
	camera = GameCamera.new()
	m.add_child(camera)
	camera.current = true
	vfx = VFX.new()
	vfx.camera = camera
	m.add_child(vfx)
	projectiles = ProjectileView.new()
	m.add_child(projectiles)
	field = FieldView.new()
	field.my_team = my_team
	m.add_child(field)
	aim_line = MeshInstance3D.new()
	aim_line.mesh = Mats.quad(Vector2(2, 2))
	aim_line.material_override = Mats.ring()
	aim_line.visible = false
	aim_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(aim_line)
	hud = HUD.new()
	m.add_child(hud)
	hud.setup(m, my_team)
	touch = hud.touch
	if me:
		camera.setup(me, my_team)
		input = PlayerInput.new()
		m.add_child(input)
		input.setup(touch, camera, me, m)
		touch.ability_name = me.data.ability.display_name.split(" ")[0]
		touch.super_name = me.data.super_ability.display_name.split(" ")[0]
	Audio.play_music(&"battle")


# ----------------------------------------------------------------- input (physics rate)
func physics_tick(dt: float) -> void:
	var me := m.local_hero()
	if me == null or input == null or m.phase == Match.Phase.ENDED or me.is_bot:
		return   # (is_bot on the local hero = autopilot used by automated tests / AFK takeover)
	var cmd := input.sample()
	_seq += 1
	if m.is_server:
		me.in_move = cmd.move
		me.in_aim = cmd.aim
		me.in_fire = cmd.fire
		me.input_seq = _seq
		for a in cmd.actions:
			me.in_actions.append(a)
	else:
		m.rpc_input.rpc_id(1, _seq, cmd.move.x, cmd.move.z, cmd.aim.x, cmd.aim.z, cmd.fire)
		for a in cmd.actions:
			m.rpc_action.rpc_id(1, String(a.slot), a.dir.x, a.dir.z, a.mag)
		# prediction: move our own hero immediately with the same physics as the server
		if me.alive and me.dash.is_empty() and m.phase == Match.Phase.PLAYING and not me.get_meta(&"dashing", false):
			me.slow_factor = _me_info[4] if _me_info.size() > 4 else 1.0
			me.step_move(cmd.move, dt)
		me.in_fire = cmd.fire
		me.in_aim = cmd.aim
	if cmd.fire and cmd.aim.length_squared() > 0.01:
		me.facing = cmd.aim


# ----------------------------------------------------------------- per frame visuals
func _process(delta: float) -> void:
	Prof.begin("view")
	if not m.is_server:
		_interpolate()
	var me := m.local_hero()
	for h: Hero in m.heroes.values():
		var v := h.visual
		var seen := m.visible_to(h, my_team)
		h.visible = (seen or h.team == my_team)
		v.set_hp(h.hp_frac())
		v.set_carried(h.carried, h.carried >= m.mode_data.reveal_carry)
		v.set_status(m.time < h.slow_until or h.get_meta(&"slowed", false), h.is_protected(m.time) or h.get_meta(&"protected", false))
		v.set_in_bush(h.bush >= 0 and h.team == my_team)
		v.set_facing(h.facing)
		if h.id == m.local_id:
			v.set_super_ready(h.super_charge >= 1.0)
		if h.bush >= 0 and h.velocity.length() > 1.0:
			m.map.rustle_bush(h.bush, 1.0)
	# bushes become see-through around the local hero
	if me:
		m.map.set_bush_reveal(me.position, me.bush)
		var lead := me.velocity * 0.25
		if input and input.aim_source != &"none":
			lead += input.aim * 1.6
		lead.y = 0.0
		camera.lead = camera.lead.lerp(lead.limit_length(3.0), minf(1.0, delta * 3.0))
		camera.target_zoom = 1.12 if (input and not touch.preview.is_empty() and touch.preview.slot == &"super") else 1.0
		_update_aim_indicator(me)
		touch.ability_cd = clampf(me.cd[&"ability"] / maxf(me.data.ability.cooldown, 0.01), 0.0, 1.0)
		touch.super_charge = me.super_charge
	Prof.end("view")
	hud.refresh(delta)


func _update_aim_indicator(me: Hero) -> void:
	var p := input.preview() if input else {"kind": &"none"}
	if not me.alive or p.kind == &"none":
		aim_line.visible = false
		return
	aim_line.visible = true
	var col := Color(1, 1, 1, 0.55)
	if p.kind == &"line":
		# a long thin wedge: use the ring shader's arc mode with a tiny angle, scaled to range
		var ang := atan2(-p.dir.z, p.dir.x)
		aim_line.global_position = me.position + Vector3(0, 0.07, 0)
		aim_line.rotation = Vector3(0, ang, 0)
		aim_line.scale = Vector3(p.len, 1, p.len)
		aim_line.set_instance_shader_parameter(&"arc", 0.09)
		aim_line.set_instance_shader_parameter(&"progress", 0.98)
		aim_line.set_instance_shader_parameter(&"thickness", 0.04)
		aim_line.set_instance_shader_parameter(&"fill", 0.55)
		aim_line.set_instance_shader_parameter(&"color", col)
		aim_line.set_instance_shader_parameter(&"alpha", 0.7)
		aim_line.set_instance_shader_parameter(&"dashes", 0.0)
	elif p.kind == &"cone":
		aim_line.global_position = me.position + Vector3(0, 0.07, 0)
		aim_line.rotation = Vector3(0, atan2(-p.dir.z, p.dir.x), 0)
		aim_line.scale = Vector3(p.len, 1, p.len)
		aim_line.set_instance_shader_parameter(&"arc", deg_to_rad(p.radius))
		aim_line.set_instance_shader_parameter(&"progress", 0.97)
		aim_line.set_instance_shader_parameter(&"thickness", 0.05)
		aim_line.set_instance_shader_parameter(&"fill", 0.4)
		aim_line.set_instance_shader_parameter(&"color", col)
		aim_line.set_instance_shader_parameter(&"alpha", 0.6)
	else:
		var center: Vector3 = me.position + p.dir * p.len
		aim_line.global_position = Vector3(center.x, 0.08, center.z)
		aim_line.rotation = Vector3.ZERO
		aim_line.scale = Vector3(p.radius, 1, p.radius)
		aim_line.set_instance_shader_parameter(&"arc", 6.3)
		aim_line.set_instance_shader_parameter(&"progress", 0.95)
		aim_line.set_instance_shader_parameter(&"thickness", 0.05)
		aim_line.set_instance_shader_parameter(&"fill", 0.3)
		aim_line.set_instance_shader_parameter(&"color", Color(1, 0.85, 0.4, 0.8))
		aim_line.set_instance_shader_parameter(&"alpha", 0.8)
		aim_line.set_instance_shader_parameter(&"dashes", 10.0)


# ----------------------------------------------------------------- client snapshots
func on_snapshot(s: Array) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var off: float = s[0] - now
	if not _have_clock or absf(off - _clock_offset) > 0.5:
		_clock_offset = off
		_have_clock = true
	else:
		_clock_offset = lerpf(_clock_offset, off, 0.05)
	m.time = s[0]
	m.phase = s[1]
	m.mode.score = [int(s[2]), int(s[3])]
	m.set_meta(&"time_left", s[4])
	m.set_meta(&"pulse_in", s[5])
	var by_id := {}
	for a in s[6]:
		by_id[int(a[0])] = a
	_snaps.append({"t": s[0], "h": by_id})
	if _snaps.size() > 20:
		_snaps.pop_front()
	_me_info = s[8]
	for h: Hero in m.heroes.values():
		var a = by_id.get(h.id)
		h.set_meta(&"seen", a != null)
		if a == null:
			continue
		var flags: int = a[6]
		h.hp = a[5]
		h.carried = a[7]
		h.bush = 0 if flags & 2 else -1
		h.set_meta(&"slowed", flags & 8 != 0)
		h.set_meta(&"protected", flags & 4 != 0)
		h.set_meta(&"dashing", flags & 16 != 0)
		if h.id != m.local_id:
			h.facing = Vector3(a[3], 0, a[4])
		var alive := flags & 1 == 0
		h.alive = alive
	var me := m.local_hero()
	if me and _me_info.size() >= 5:
		me.cd[&"ability"] = _me_info[1]
		me.super_charge = _me_info[2]
		me.set_meta(&"respawn_in", _me_info[3])
		var a2 = by_id.get(me.id)
		if a2:
			var server_pos := Vector3(a2[1], 0, a2[2])
			var err := me.position.distance_to(server_pos)
			if err > 1.6 or not me.alive or me.get_meta(&"dashing", false):
				me.position = server_pos        # big correction / server-driven motion: snap
			elif err > 0.05:
				me.position = me.position.lerp(server_pos, 0.25)   # soft reconciliation
	projectiles.sync_homing(s[7])
	if s[9].size() > 0:
		field.sync_shards(s[9])


func _interpolate() -> void:
	if _snaps.size() < 1:
		return
	var rt := Time.get_ticks_msec() / 1000.0 + _clock_offset - INTERP_DELAY
	var a: Dictionary = _snaps[0]
	var b: Dictionary = _snaps[_snaps.size() - 1]
	for i in range(_snaps.size() - 1, 0, -1):
		if _snaps[i - 1].t <= rt:
			a = _snaps[i - 1]
			b = _snaps[i]
			break
	var k := 1.0
	if b.t > a.t:
		k = clampf((rt - a.t) / (b.t - a.t), 0.0, 1.0)
	for h: Hero in m.heroes.values():
		if h.id == m.local_id:
			continue
		var pb = b.h.get(h.id)
		if pb == null:
			continue
		var pa = a.h.get(h.id, pb)
		var target := Vector3(lerpf(pa[1], pb[1], k), 0, lerpf(pa[2], pb[2], k))
		if h.position.distance_to(target) > 4.0:
			h.position = target
		else:
			h.position = target
		h.velocity = Vector3(pb[1] - pa[1], 0, pb[2] - pa[2]) / maxf(b.t - a.t, 0.001)


# ----------------------------------------------------------------- events -> feedback
func on_events(evs: Array) -> void:
	for e in evs:
		_event(e)


func _hero(id) -> Hero:
	return m.heroes.get(int(id))


func _near_local(pos: Vector3, r := 9.0) -> bool:
	var me := m.local_hero()
	return me != null and me.position.distance_to(pos) < r


func _event(e: Dictionary) -> void:
	match e.t:
		"go":
			hud.announce("FIGHT!", Color("ffd23f"))
			Audio.play(&"go")
		"cast":
			var h := _hero(e.p)
			if h == null:
				return
			h.facing = Vector3(e.dx, 0, e.dz)
			h.visual.set_facing(h.facing, true)
			var def := h.data.slot(StringName(e.s))
			h.visual.play_action(def.anim)
			_cast_fx(h, StringName(e.s), def, Vector3(e.dx, 0, e.dz))
		"ps":
			var o := _hero(e.o)
			var muzzle := o.visual.muzzle_position() if o and o.visual and o.visible else Vector3.INF
			projectiles.spawn(e, muzzle)
			if o and o.visual and (e.k == "bolt" or e.k == "dart"):
				vfx.burst(&"muzzle", muzzle if muzzle != Vector3.INF else o.position + Vector3(0, 1, 0), Color("bffcff") if e.k == "bolt" else Color("d6b3ff"), 1.0, Vector3(e.dx, 0.2, e.dz))
		"pe":
			var pos := projectiles.finish(e.id)
			if pos == Vector3.INF:
				pos = Vector3(e.x, 0.95, e.z)
			if e.b > 0.0:
				_overload_blast(Vector3(e.x, 0, e.z), e.b)
			else:
				vfx.burst(&"impact", pos, Color("bffcff") if e.k == "bolt" else Color("e0c2ff"), 1.0, Vector3.UP)
		"hit":
			var v := _hero(e.v)
			if v == null:
				return
			var heavy: bool = e.h
			v.visual.hit(1.0 if heavy else 0.4)
			var col := Color("ff5a5a") if v.id == m.local_id else (Color("ffffff") if v.team != my_team else Color("ffb3b3"))
			var mine_involved := v.id == m.local_id or int(e.s) == m.local_id
			if v.visible and (int(e.a) >= 100 or mine_involved):
				vfx.number(v.position, str(e.a), col, heavy)
				vfx.burst(&"spark", v.position + Vector3(0, 1.0, 0), Color("fff2b3") if heavy else Color("ffe6ff"), 1.3 if heavy else 0.9)
			Audio.play_at(&"hit_heavy" if heavy else &"hit", v.position, 0.0 if heavy else -4.0)
			if v.id == m.local_id:
				vfx.shake(0.25 if heavy else 0.1)
				hud.damage_flash()
			elif int(e.s) == m.local_id:
				vfx.shake(0.06 if not heavy else 0.12)
		"heal":
			var v2 := _hero(e.v)
			if v2 and v2.visible:
				vfx.number(v2.position, "+" + str(e.a), Color("6bff9a"))
				vfx.burst(&"heal", v2.position + Vector3(0, 0.6, 0), Color("6bff9a"), 1.0)
		"kill":
			var victim := _hero(e.v)
			var killer := _hero(e.k)
			if victim:
				victim.visual.die()
				var p := Vector3(e.x, 0, e.z)
				vfx.burst(&"death", p + Vector3(0, 1.0, 0), Settings.TEAM_COLORS[victim.team], 1.4)
				vfx.burst(&"smoke", p + Vector3(0, 0.5, 0), Color(0.5, 0.45, 0.6, 0.7), 1.2)
				vfx.ring(p, 0.3, 2.6, Settings.TEAM_COLORS[victim.team], 0.5)
				vfx.flash(p, Settings.TEAM_COLORS[victim.team], 4.0, 6.0, 0.3)
				Audio.play_at(&"elim", p)
				if killer and killer.id == m.local_id:
					vfx.shake(0.35)
					hud.announce("ELIMINATED %s" % victim.player_name, Color("ffd23f"))
				if victim.id == m.local_id:
					vfx.shake(0.5)
			hud.kill_feed(killer, victim)
		"spawn":
			var h2 := _hero(e.p)
			if h2:
				h2.position = Vector3(e.x, 0, e.z)
				h2.visual.respawn()
				vfx.burst(&"spawn", h2.position, Settings.TEAM_COLORS[h2.team], 1.0)
				vfx.ring(h2.position, 2.2, 0.4, Settings.TEAM_COLORS[h2.team], 0.45)
				if _near_local(h2.position, 12.0):
					Audio.play_at(&"respawn", h2.position)
		"fx":
			_fx(e)
		"zs":
			field.add_zone(e)
			var col := Color("5dff9d") if e.e == "heal" else Color("c67bff")
			vfx.ring(Vector3(e.x, 0, e.z), 0.3, e.r, col, 0.35, 0.0, 0.1)
			vfx.burst(&"heal" if e.e == "heal" else &"energy", Vector3(e.x, 0.5, e.z), col, 0.8)
		"ze":
			field.remove_zone(e.id)
		"ss":
			field.add_shard(e.id, Vector3(e.x, 0, e.z), Vector3(e.fx, 2.5, e.fz))
		"sp":
			var pos2 := field.remove_shard(e.id)
			var h3 := _hero(e.p)
			if pos2 != Vector3.INF:
				vfx.burst(&"pickup", pos2 + Vector3(0, 0.6, 0), Color("ffd84a"), 1.0)
			if h3:
				h3.carried = e.n
				if h3.id == m.local_id:
					Audio.play(&"pickup", -2.0, 1.0 + h3.carried * 0.04)
		"se":
			var pos3 := field.remove_shard(e.id)
			if pos3 != Vector3.INF:
				vfx.burst(&"smoke", pos3 + Vector3(0, 0.4, 0), Color(1, 0.85, 0.4, 0.5), 0.5)
		"dep":
			var tm: int = e.tm
			m.mode.score = e.sc
			m.map.uplinks[tm].flash()
			var up := m.map.uplink_pos(tm)
			vfx.ring(up, 0.8, 3.2, Settings.TEAM_COLORS[tm], 0.5)
			vfx.burst(&"pickup", up + Vector3(0, 1.0, 0), Color("ffd84a"), 1.5, Vector3.UP)
			Audio.play(&"deposit" if tm == my_team else &"score_enemy", -2.0)
			hud.score_pop(tm)
		"pulse":
			m.map.core_view.pulse()
			vfx.ring(Vector3.ZERO, 1.5, 6.0, Color("6ff6ff"), 0.8)
			vfx.flash(Vector3.ZERO, Color("6ff6ff"), 5.0, 9.0, 0.5)
			if e.get("surge", false) and not m.has_meta(&"surge_announced"):
				m.set_meta(&"surge_announced", true)
				hud.announce("ENERGY SURGE!", Color("6ff6ff"))


func _cast_fx(h: Hero, slot: StringName, def: AbilityData, dir: Vector3) -> void:
	var p := h.position
	match def.vfx:
		&"bolt":
			Audio.play_at(&"zap", p, -3.0)
		&"dart":
			Audio.play_at(&"dart", p, -2.0)
		&"swing":
			vfx.arc(p, dir, def.range, def.arc_deg, Color("ffd9a8"))
			Audio.play_at(&"hammer", p)
		&"overload":
			Audio.play_at(&"super_volt", p)
			vfx.burst(&"energy", h.visual.muzzle_position(), Color("fff36b"), 0.7, dir)
			if h.id == m.local_id:
				vfx.shake(0.2)
		&"dash":
			Audio.play_at(&"charge", p)
			vfx.burst(&"dust", p + Vector3(0, 0.2, 0), Color(0.75, 0.68, 0.8, 0.8), 1.2, -dir + Vector3.UP * 0.5)
		&"quake":
			Audio.play_at(&"super_brute", p)
			vfx.ring(p, 0.5, 1.4, Color("ffb35c"), 0.4, 0.0, 0.06)
		&"blink":
			Audio.play_at(&"blink", p)
		&"stasis":
			Audio.play_at(&"stasis", p)
		&"bloom":
			Audio.play_at(&"super_nyx", p)


func _fx(e: Dictionary) -> void:
	match e.f:
		"blink":
			var a := Vector3(e.x, 0, e.z)
			var b := Vector3(e.x2, 0, e.z2)
			vfx.burst(&"energy", a + Vector3(0, 0.9, 0), Color("6ff6ff"), 0.55)
			vfx.burst(&"energy", b + Vector3(0, 0.9, 0), Color("bffcff"), 0.55)
			vfx.ring(a, 1.3, 0.2, Color("6ff6ff"), 0.3)
			vfx.ring(b, 0.2, 1.6, Color("6ff6ff"), 0.35)
			var h := _hero(e.p)
			if h:
				if h.id != m.local_id or m.is_server:
					h.position = b
				h.visual.hit(0.0)   # brief flash = "phase" look
		"dash_end":
			vfx.burst(&"dust", Vector3(e.x, 0.2, e.z), Color(0.75, 0.68, 0.8, 0.8), 0.9)
		"quake":
			var p := Vector3(e.x, 0, e.z)
			vfx.ring(p, 0.6, e.r, Color("ffb35c"), 0.55, 0.0, 0.12, 0.25)
			vfx.ring(p, 0.3, e.r * 0.85, Color("fff2d6"), 0.4, 0.05, 0.05)
			vfx.ring(p, e.r * 0.95, e.r, Color("ff7a2b"), 1.4, 0.0, 0.02, 0.0, 1.0)    # ground cracks linger
			vfx.burst(&"dust", p + Vector3(0, 0.2, 0), Color(0.78, 0.66, 0.55, 0.9), 2.4)
			vfx.burst(&"debris", p + Vector3(0, 0.3, 0), Color("6a5a7a"), 1.4)
			vfx.burst(&"spark", p + Vector3(0, 0.4, 0), Color("ffcc66"), 1.8)
			vfx.flash(p, Color("ffab4a"), 6.0, 9.0, 0.35)
			vfx.shake(0.75 if _near_local(p, 10.0) else 0.25)


func _overload_blast(p: Vector3, r: float) -> void:
	vfx.burst(&"energy", p + Vector3(0, 0.8, 0), Color("fff36b"), 1.8)
	vfx.burst(&"energy", p + Vector3(0, 0.8, 0), Color("6ff6ff"), 1.3)
	vfx.burst(&"smoke", p + Vector3(0, 0.6, 0), Color(0.55, 0.5, 0.7, 0.7), 1.6)
	vfx.burst(&"spark", p + Vector3(0, 0.5, 0), Color("fffbe0"), 2.2)
	vfx.ring(p, 0.4, r, Color("fff36b"), 0.45, 0.0, 0.12, 0.35)
	vfx.ring(p, 0.2, r * 1.25, Color("6ff6ff"), 0.6, 0.06, 0.04)
	vfx.flash(p, Color("fff0a0"), 7.0, 10.0, 0.4)
	Audio.play_at(&"hit_heavy", p, 2.0, 0.7)
	vfx.shake(0.65 if _near_local(p, 10.0) else 0.2)


func _on_footstep(pos: Vector3, heavy: bool, h: Hero) -> void:
	if not h.visible or h.bush >= 0:
		return
	vfx.burst(&"step", pos + Vector3(0, 0.08, 0), Color(0.75, 0.75, 0.9, 0.35), 1.6 if heavy else 1.0)
	if h.id == m.local_id or (heavy and _near_local(pos, 7.0)):
		Audio.play_at(&"step_heavy" if heavy else &"step_light", pos, -8.0 if not heavy else -2.0)
	if heavy and _near_local(pos, 6.0):
		vfx.shake(0.03)


func on_match_end(res: Dictionary) -> void:
	var won: bool = res.winner == my_team
	for h: Hero in m.heroes.values():
		h.visual.set_end_state(res.winner == h.team)
	if touch:
		touch.release_all()
		touch.visible = false
	aim_line.visible = false
	projectiles.clear()
	Audio.stop_music()
	if res.winner == -1:
		hud.announce("DRAW", Color("c8c8ff"), 2.8)
		Audio.play(&"defeat")
	elif won:
		hud.announce("VICTORY!", Color("ffd23f"), 2.8)
		Audio.play(&"victory")
		vfx.shake(0.3)
	else:
		hud.announce("DEFEAT", Color("ff5a6a"), 2.8)
		Audio.play(&"defeat")
	# celebrate around the winners' uplink
	if res.winner >= 0:
		var up := m.map.uplink_pos(res.winner)
		for i in 3:
			vfx.burst(&"pickup", up + Vector3(randf_range(-1.5, 1.5), 1.5, randf_range(-1.5, 1.5)), Settings.TEAM_COLORS[res.winner], 2.0)
		m.map.uplinks[res.winner].flash()
