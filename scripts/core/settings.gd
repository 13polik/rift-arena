extends Node
## Autoload "Settings": player preferences, graphics quality presets, input map, shared constants.

enum Quality { LOW, MEDIUM, HIGH }

const TEAM_COLORS: Array[Color] = [Color("3d8bff"), Color("ff4257")]
const TEAM_DARK: Array[Color] = [Color("1c3f8f"), Color("8f1c2c")]
const TEAM_NAMES: Array[String] = ["BLUE", "RED"]
const HEROES: Array[StringName] = [&"volt", &"brute", &"nyx"]
const SAVE_PATH := "user://settings.cfg"

var quality: Quality = Quality.MEDIUM
var player_name := ""
var hero: StringName = &"volt"
var last_address := ""
## Internet server (WebSocket). Players can change it in SETTINGS to use their own server.
const ONLINE_SERVER_DEFAULT := "wss://rift-arena-enm7.onrender.com"
var online_server := ONLINE_SERVER_DEFAULT
var music_volume := 0.6
var sfx_volume := 0.9
var show_fps := false
var fps_cap := 0   ## 0 = display refresh rate (60/90/120/144)
# progression (local save)
var coins := 100
var owned_skins: Array = []
var equipped := {}   # hero id (String) -> skin index
var matches_played := 0
var wins := 0

signal quality_changed


func _ready() -> void:
	_register_inputs()
	_load()
	if player_name.is_empty():
		player_name = "Pilot%d" % randi_range(100, 999)
	apply_engine_settings()


func hero_data(id: StringName) -> HeroData:
	return load("res://resources/heroes/%s.tres" % id)


## Called once at boot and when the player changes quality in SETTINGS.
func apply_engine_settings() -> void:
	Engine.max_fps = fps_cap
	var vp := get_viewport()
	match quality:
		Quality.LOW:
			vp.scaling_3d_scale = 0.7
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		Quality.MEDIUM:
			vp.scaling_3d_scale = 0.85
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		Quality.HIGH:
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	AudioServer.set_bus_volume_db(0, 0.0)
	quality_changed.emit()


## Per-match environment knobs derived from quality.
func shadows_enabled() -> bool: return quality == Quality.HIGH
func glow_enabled() -> bool: return quality != Quality.LOW
func particle_scale() -> float: return [0.4, 0.75, 1.0][quality]


func skin_for(id: StringName) -> int:
	return int(equipped.get(String(id), 0))


func set_quality(q: int) -> void:
	quality = q as Quality
	apply_engine_settings()
	save()


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("player", "name", player_name)
	cf.set_value("player", "hero", hero)
	cf.set_value("player", "address", last_address)
	cf.set_value("player", "online_server", online_server)
	cf.set_value("video", "quality", quality)
	cf.set_value("video", "fps_cap", fps_cap)
	cf.set_value("video", "show_fps", show_fps)
	cf.set_value("audio", "music", music_volume)
	cf.set_value("audio", "sfx", sfx_volume)
	cf.set_value("progress", "coins", coins)
	cf.set_value("progress", "owned", owned_skins)
	cf.set_value("progress", "equipped", equipped)
	cf.set_value("progress", "matches", matches_played)
	cf.set_value("progress", "wins", wins)
	cf.save(SAVE_PATH)


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		# first launch: pick a sensible default for the device
		quality = Quality.MEDIUM if OS.has_feature("mobile") else Quality.HIGH
		return
	player_name = cf.get_value("player", "name", "")
	hero = cf.get_value("player", "hero", &"volt")
	last_address = cf.get_value("player", "address", "")
	online_server = cf.get_value("player", "online_server", ONLINE_SERVER_DEFAULT)
	if online_server.is_empty():
		online_server = ONLINE_SERVER_DEFAULT
	quality = cf.get_value("video", "quality", Quality.MEDIUM)
	fps_cap = cf.get_value("video", "fps_cap", 0)
	show_fps = cf.get_value("video", "show_fps", false)
	music_volume = cf.get_value("audio", "music", 0.6)
	sfx_volume = cf.get_value("audio", "sfx", 0.9)
	coins = cf.get_value("progress", "coins", 100)
	owned_skins = cf.get_value("progress", "owned", [])
	equipped = cf.get_value("progress", "equipped", {})
	matches_played = cf.get_value("progress", "matches", 0)
	wins = cf.get_value("progress", "wins", 0)


## Desktop / gamepad bindings through the Godot InputMap (touch is handled by the on-screen controls).
func _register_inputs() -> void:
	var keys := {
		&"move_left": [KEY_A, KEY_LEFT], &"move_right": [KEY_D, KEY_RIGHT],
		&"move_up": [KEY_W, KEY_UP], &"move_down": [KEY_S, KEY_DOWN],
		&"ability": [KEY_E, KEY_SHIFT], &"super": [KEY_Q, KEY_SPACE],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action(&"attack"):
		InputMap.add_action(&"attack")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(&"attack", mb)
	# gamepad
	var pad := {&"move_left": [JOY_AXIS_LEFT_X, -1.0], &"move_right": [JOY_AXIS_LEFT_X, 1.0], &"move_up": [JOY_AXIS_LEFT_Y, -1.0], &"move_down": [JOY_AXIS_LEFT_Y, 1.0]}
	for action in pad:
		var jm := InputEventJoypadMotion.new()
		jm.axis = pad[action][0]
		jm.axis_value = pad[action][1]
		InputMap.action_add_event(action, jm)
	for pair in [[&"attack", JOY_BUTTON_RIGHT_SHOULDER], [&"ability", JOY_BUTTON_LEFT_SHOULDER], [&"super", JOY_BUTTON_Y]]:
		var jb := InputEventJoypadButton.new()
		jb.button_index = pair[1]
		InputMap.action_add_event(pair[0], jb)
