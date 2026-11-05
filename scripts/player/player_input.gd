class_name PlayerInput
extends Node
## Local player's input: merges TouchControls, the InputMap (keyboard / gamepad) and mouse aiming into
## world-space commands. Includes aim assist: stick aim snaps to an enemy inside a narrow cone, and the ATTACK
## button / quick-cast pick the best visible target (closest, preferring energy carriers and low-HP heroes).

const ASSIST_CONE := deg_to_rad(14.0)

var touch: TouchControls
var camera: GameCamera
var hero: Hero
var game: Match

var aim := Vector3.FORWARD
var aim_source := &"none"     # stick | mouse | auto | none  (drives the aim indicator)
var _actions: Array = []
var _mouse_seen := -10.0


func setup(p_touch: TouchControls, p_camera: GameCamera, p_hero: Hero, p_game: Match) -> void:
	touch = p_touch
	camera = p_camera
	hero = p_hero
	game = p_game
	aim = hero.facing
	touch.action.connect(_on_touch_action)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_seen = Time.get_ticks_msec() / 1000.0
	if event.is_action_pressed(&"ability"):
		_actions.append({"slot": &"ability", "dir": Vector3.ZERO, "mag": -1.0})
	elif event.is_action_pressed(&"super"):
		_actions.append({"slot": &"super", "dir": Vector3.ZERO, "mag": -1.0})


func _on_touch_action(slot: StringName, dir: Vector2, mag: float, manual: bool) -> void:
	if slot == &"attack":
		# released aim stick: one manual shot in that direction (with a little assist)
		var w := _assist(_s2w(dir), hero.data.attack.range + 1.0)
		_actions.append({"slot": &"attack", "dir": w, "mag": 1.0})
	elif manual:
		_actions.append({"slot": slot, "dir": _s2w(dir), "mag": mag})
	else:
		_actions.append({"slot": slot, "dir": Vector3.ZERO, "mag": -1.0})


func _s2w(v: Vector2) -> Vector3:
	return Vector3(v.x, 0, v.y) * camera.flip


func _mouse_active() -> bool:
	return Time.get_ticks_msec() / 1000.0 - _mouse_seen < 3.0 and not touch._touch.has(99)


## Called once per physics tick. Returns the command for this tick.
func sample() -> Dictionary:
	var mv := touch.move
	if mv.length_squared() < 0.0001:
		mv = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var move := _s2w(mv)
	var fire := false
	aim_source = &"none"
	var rng := hero.data.attack.range
	if touch.aim_active:
		aim = _assist(_s2w(touch.aim), rng + 1.0)
		fire = touch.aim_fire
		aim_source = &"stick"
	elif _mouse_active():
		var g := camera.screen_to_ground(get_viewport().get_mouse_position(), 0.9)
		var d := Vector3(g.x - hero.position.x, 0, g.z - hero.position.z)
		if d.length() > 0.2:
			aim = d.normalized()
		fire = Input.is_action_pressed(&"attack")
		aim_source = &"mouse"
	if touch.attack_held or (Input.is_action_pressed(&"attack") and not _mouse_active() and Input.get_connected_joypads().size() > 0):
		fire = true
		var t := best_target(rng + 1.5)
		if t:
			aim = (t.position - hero.position).normalized()
			aim_source = &"auto"
		elif move.length() > 0.1:
			aim = move.normalized()
	aim.y = 0.0
	# resolve queued actions into world directions
	var acts := []
	for a in _actions:
		var def := hero.data.slot(a.slot)
		var dir: Vector3 = a.dir
		var mag: float = a.mag
		if dir == Vector3.ZERO:
			if _mouse_active():
				var g2 := camera.screen_to_ground(get_viewport().get_mouse_position(), 0.0)
				var d2 := Vector3(g2.x - hero.position.x, 0, g2.z - hero.position.z)
				dir = d2.normalized() if d2.length() > 0.2 else aim
				mag = clampf(d2.length() / maxf(def.cast_range, 0.1), 0.0, 1.0) if def.cast_range > 0.0 else 1.0
			else:
				var reach := def.cast_range if def.cast_range > 0.0 else maxf(def.range, rng)
				var t2 := best_target(reach + 2.0)
				if def.zone_effect == &"heal" and def.kind == AbilityData.Kind.ZONE:
					dir = aim
					mag = 0.0      # quick-cast heal lands on yourself
				elif t2:
					var d3 := t2.position - hero.position
					dir = d3.normalized()
					mag = clampf(d3.length() / maxf(def.cast_range, 0.1), 0.0, 1.0) if def.cast_range > 0.0 else 1.0
				else:
					dir = move.normalized() if move.length() > 0.1 else hero.facing
					mag = 1.0
		acts.append({"slot": a.slot, "dir": dir, "mag": maxf(mag, 0.0)})
	_actions.clear()
	return {"move": move, "aim": aim, "fire": fire, "actions": acts}


## Aim preview for the indicator: {kind: line|circle|none, dir, len, radius}
func preview() -> Dictionary:
	if not touch.preview.is_empty():
		var def := hero.data.slot(touch.preview.slot)
		var dir := _s2w(touch.preview.dir)
		match def.kind:
			AbilityData.Kind.ZONE:
				return {"kind": &"circle", "dir": dir, "len": def.cast_range * touch.preview.mag, "radius": def.zone_radius}
			AbilityData.Kind.SHOCKWAVE:
				return {"kind": &"circle", "dir": dir, "len": 0.0, "radius": def.range}
			_:
				return {"kind": &"line", "dir": dir, "len": def.range, "radius": def.blast_radius}
	if aim_source == &"stick" or aim_source == &"mouse":
		var a := hero.data.attack
		if a.kind == AbilityData.Kind.MELEE:
			return {"kind": &"cone", "dir": aim, "len": a.range, "radius": a.arc_deg}
		return {"kind": &"line", "dir": aim, "len": a.range, "radius": 0.0}
	return {"kind": &"none"}


func _assist(dir: Vector3, rng: float) -> Vector3:
	if dir.length_squared() < 0.0001:
		return dir
	dir = dir.normalized()
	var best: Hero = null
	var best_a := ASSIST_CONE
	for h: Hero in game.heroes.values():
		if h.team == hero.team or not h.alive or not game.visible_to(h, hero.team):
			continue
		var to := h.position - hero.position
		to.y = 0.0
		if to.length() > rng:
			continue
		var a := absf(dir.signed_angle_to(to.normalized(), Vector3.UP))
		if a < best_a:
			best_a = a
			best = h
	return (best.position - hero.position).normalized() if best else dir


func best_target(rng: float) -> Hero:
	var best: Hero = null
	var best_score := INF
	for h: Hero in game.heroes.values():
		if h.team == hero.team or not h.alive or not game.visible_to(h, hero.team):
			continue
		var d := Vector2(h.position.x - hero.position.x, h.position.z - hero.position.z).length()
		if d > rng:
			continue
		var score := d - (2.0 if h.carried > 0 else 0.0) - (1.0 - h.hp_frac()) * 2.0
		if score < best_score:
			best_score = score
			best = h
	return best
