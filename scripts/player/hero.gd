class_name Hero
extends CharacterBody3D
## One hero in a match (player or bot). On the SERVER this node is authoritative: it is moved with
## move_and_slide() against the map colliders and owns HP / cooldowns / super charge.
## On CLIENTS it is a puppet placed from snapshots (the local player's hero is predicted).

const WORLD_MASK := 1

var id := 0                      # unique hero id in the match (== peer id for humans, negative for bots)
var player_name := ""
var team := 0
var is_bot := false
var data: HeroData
var visual: HeroVisual

# --- authoritative state (server) ---
var hp := 0.0
var alive := true
var respawn_at := 0.0
var invuln_until := 0.0
var last_damaged_at := -99.0
var last_attack_at := -99.0
var cd := {&"attack": 0.0, &"ability": 0.0}
var super_charge := 0.0
var slow_until := 0.0
var slow_factor := 1.0
var knockback := Vector3.ZERO
var carried := 0
var deposit_timer := 0.0
var bush := -1
var dash := {}                   # active charge
var pending := []                # scheduled effects: [{at, kind, ...}] (melee windups, slam, burst volleys)
var spawn_point := Vector3.ZERO
var stats := {"kills": 0, "deaths": 0, "delivered": 0, "damage": 0, "healing": 0}

# --- input (written by PlayerInput locally, by RPC on the server, or by a BotBrain) ---
var in_move := Vector3.ZERO      # world-space, length <= 1
var in_aim := Vector3.FORWARD    # world-space unit vector
var in_fire := false
var in_actions: Array = []       # [{slot, dir: Vector3, mag}]
var input_seq := 0

# --- presentation helpers ---
var facing := Vector3.FORWARD
var anim_state := &"alive"


func setup(p_id: int, p_name: String, p_team: int, p_data: HeroData, bot := false) -> void:
	id = p_id
	player_name = p_name
	team = p_team
	data = p_data
	is_bot = bot
	name = "Hero_%d" % p_id if p_id >= 0 else "Bot_%d" % -p_id
	hp = data.max_hp
	collision_layer = 2
	collision_mask = WORLD_MASK
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = data.radius
	sh.height = 1.6
	cs.shape = sh
	cs.position.y = 0.8
	add_child(cs)
	facing = Vector3(1, 0, 0) if team == 0 else Vector3(-1, 0, 0)
	in_aim = facing


func make_visual(is_local: bool, is_ally: bool) -> void:
	visual = HeroVisual.new()
	add_child(visual)
	visual.setup(data, is_ally, is_local, player_name)
	visual.set_facing(facing, true)


func hp_frac() -> float:
	return hp / float(data.max_hp)


func speed() -> float:
	return data.move_speed * slow_factor


func is_protected(now: float) -> bool:
	return now < invuln_until


## Server + local prediction share this: one movement step against the map colliders.
func step_move(move: Vector3, dt: float) -> void:
	var v := move.limit_length(1.0) * speed()
	if dash.size() > 0:
		v = dash.vel
	velocity = v + knockback
	move_and_slide()
	position.y = 0.0
	knockback = knockback.move_toward(Vector3.ZERO, 18.0 * dt)
	if move.length_squared() > 0.01 and not in_fire:
		facing = move.normalized()


func flags(now: float) -> int:
	var f := 0
	if not alive: f |= 1
	if bush >= 0: f |= 2
	if now < invuln_until: f |= 4
	if now < slow_until: f |= 8
	if dash.size() > 0: f |= 16
	return f
