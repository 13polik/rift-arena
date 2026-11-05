class_name HeroAnimator
extends RefCounted
## Wires an AnimationPlayer + AnimationTree for a hero:
##   loco (BlendSpace1D idle/walk/run) -> speed(TimeScale) -> act (OneShot: attack/ability/super/respawn)
##   -> hit (OneShot) -> state (Transition: alive/dead/victory/defeat) -> output

var player: AnimationPlayer
var tree: AnimationTree
var _act_anim: AnimationNodeAnimation
var _state := "alive"


func setup(root: Node3D, lib: AnimationLibrary) -> void:
	player = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.add_animation_library(&"", lib)

	var bt := AnimationNodeBlendTree.new()
	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = 1.0
	for pair in [[&"idle", 0.0], [&"walk", 0.5], [&"run", 1.0]]:
		var an := AnimationNodeAnimation.new()
		an.animation = pair[0]
		loco.add_blend_point(an, pair[1], -1, pair[0])
	bt.add_node(&"loco", loco, Vector2(0, 0))
	bt.add_node(&"speed", AnimationNodeTimeScale.new(), Vector2(200, 0))
	_act_anim = AnimationNodeAnimation.new()
	_act_anim.animation = &"attack"
	bt.add_node(&"act_anim", _act_anim, Vector2(200, 200))
	var act := AnimationNodeOneShot.new()
	act.fadein_time = 0.05
	act.fadeout_time = 0.14
	bt.add_node(&"act", act, Vector2(400, 0))
	var hit_anim := AnimationNodeAnimation.new()
	hit_anim.animation = &"hit"
	bt.add_node(&"hit_anim", hit_anim, Vector2(400, 200))
	var hit := AnimationNodeOneShot.new()
	hit.fadein_time = 0.03
	hit.fadeout_time = 0.1
	bt.add_node(&"hit", hit, Vector2(600, 0))
	var state := AnimationNodeTransition.new()
	state.xfade_time = 0.12
	for n in ["alive", "dead", "victory", "defeat"]:
		state.add_input(n)
	bt.add_node(&"state", state, Vector2(800, 0))
	for n in ["death", "victory", "defeat"]:
		var a := AnimationNodeAnimation.new()
		a.animation = StringName(n)
		bt.add_node(StringName(n + "_anim"), a, Vector2(600, 200 + 100 * ["death", "victory", "defeat"].find(n)))
	bt.connect_node(&"speed", 0, &"loco")
	bt.connect_node(&"act", 0, &"speed")
	bt.connect_node(&"act", 1, &"act_anim")
	bt.connect_node(&"hit", 0, &"act")
	bt.connect_node(&"hit", 1, &"hit_anim")
	bt.connect_node(&"state", 0, &"hit")
	bt.connect_node(&"state", 1, &"death_anim")
	bt.connect_node(&"state", 2, &"victory_anim")
	bt.connect_node(&"state", 3, &"defeat_anim")
	bt.connect_node(&"output", 0, &"state")

	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	tree.tree_root = bt
	root.add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	tree.active = true
	# A Transition has no current input until one is requested -> select "alive" explicitly.
	tree.set(&"parameters/state/transition_request", "alive")


## blend: 0 idle .. 0.5 walk .. 1 run; rate scales cycle speed to actual ground speed (no foot sliding).
func set_locomotion(blend: float, rate: float) -> void:
	tree.set(&"parameters/loco/blend_position", blend)
	tree.set(&"parameters/speed/scale", rate)


func play_action(anim: StringName) -> void:
	if _state != "alive":
		return
	_act_anim.animation = anim
	tree.set(&"parameters/act/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func stop_action() -> void:
	tree.set(&"parameters/act/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


func play_hit() -> void:
	if _state == "alive":
		tree.set(&"parameters/hit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func set_state(s: String) -> void:
	if s == _state:
		return
	_state = s
	tree.set(&"parameters/state/transition_request", s)
	if s != "alive":
		tree.set(&"parameters/act/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
