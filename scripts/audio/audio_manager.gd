extends Node
## Autoload "Audio": SFX (pooled 2D + positional players), music with crossfade. All sounds come from Synth.

const SFX_NAMES: Array[StringName] = [&"step_light", &"step_heavy", &"zap", &"blink", &"super_volt", &"hammer", &"charge",
	&"super_brute", &"dart", &"stasis", &"super_nyx", &"hit", &"hit_heavy", &"elim", &"respawn", &"pickup", &"deposit",
	&"score_enemy", &"click", &"countdown", &"go", &"victory", &"defeat"]
const POOL_2D := 8
const POOL_3D := 14

var _streams := {}
var _music := {}
var _p2d: Array[AudioStreamPlayer] = []
var _p3d: Array[AudioStreamPlayer3D] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_music: StringName = &""
var _last_play := {}   # throttle identical sounds (avoids 6 identical hits stacking into noise)
var _music_thread_task := -1
var _pending_music: StringName = &""


func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for n in SFX_NAMES:
		_streams[n] = Synth.sfx(n)
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_p2d.append(p)
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		p.unit_size = 9.0
		p.max_distance = 40.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_p3d.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.bus = &"Music"
		add_child(m)
	# Music takes a moment to synthesize -> do it on a worker thread so boot stays instant.
	_music_thread_task = WorkerThreadPool.add_task(_build_music)
	apply_volumes()


func _build_music() -> void:
	var menu := Synth.music(&"menu")
	var battle := Synth.music(&"battle")
	call_deferred("_music_ready", menu, battle)


func _music_ready(menu: AudioStreamWAV, battle: AudioStreamWAV) -> void:
	_music[&"menu"] = menu
	_music[&"battle"] = battle
	if _pending_music != &"":
		play_music(_pending_music)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(Settings.music_volume, 0.001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(Settings.sfx_volume, 0.001)))


## Non-positional sound (UI, local feedback).
func play(name: StringName, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(name) or _throttled(name, 0.03):
		return
	for p in _p2d:
		if not p.playing:
			p.stream = _streams[name]
			p.volume_db = volume_db
			p.pitch_scale = pitch * randf_range(0.97, 1.03)
			p.play()
			return


## Positional sound in the arena (quieter when far from the camera).
func play_at(name: StringName, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(name) or _throttled(name, 0.025):
		return
	var best: AudioStreamPlayer3D = null
	for p in _p3d:
		if not p.playing:
			best = p
			break
	if best == null:
		best = _p3d[0]
	best.stream = _streams[name]
	best.global_position = pos
	best.volume_db = volume_db
	best.pitch_scale = pitch * randf_range(0.94, 1.06)
	best.play()


func _throttled(name: StringName, gap: float) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if _last_play.get(name, -1.0) + gap > now:
		return true
	_last_play[name] = now
	return false


func play_music(name: StringName) -> void:
	if name == _current_music:
		return
	if not _music.has(name):
		_pending_music = name
		return
	_current_music = name
	_pending_music = &""
	var from := _music_a if _music_a.playing else _music_b
	var to := _music_b if from == _music_a else _music_a
	to.stream = _music[name]
	to.volume_db = -40.0
	to.play()
	var tw := create_tween().set_parallel()
	tw.tween_property(to, "volume_db", -6.0, 1.2)
	if from.playing:
		tw.tween_property(from, "volume_db", -40.0, 1.2)
		tw.chain().tween_callback(from.stop)


func stop_music() -> void:
	_current_music = &""
	for m in [_music_a, _music_b]:
		if m.playing:
			var tw := create_tween()
			tw.tween_property(m, "volume_db", -40.0, 0.8)
			tw.tween_callback(m.stop)


func _exit_tree() -> void:
	if _music_thread_task != -1:
		WorkerThreadPool.wait_for_task_completion(_music_thread_task)
