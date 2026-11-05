extends ScreenBase
## ROOM (lobby): room code, BLUE / RED slots, hero pick, team switch, READY, FILL WITH BOTS, START (host only).

var _teams: HBoxContainer
var _ready_btn: Button
var _start_btn: Button
var _bots: CheckButton
var _hero_btn: Button
var _status: Label
var _code: Label
var _ip: Label


func _init() -> void:
	title_text = "ROOM"


func build() -> void:
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 14)
	body.add_child(top)
	top.add_child(UiTheme.label("ROOM CODE", 18, UiTheme.MUTED, false, 4))
	_code = UiTheme.label("", 44, Color("ffd23f"), true, 12)
	top.add_child(_code)
	_ip = UiTheme.label("", 14, UiTheme.MUTED, false, 4)
	top.add_child(_ip)
	_teams = HBoxContainer.new()
	_teams.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_teams.alignment = BoxContainer.ALIGNMENT_CENTER
	_teams.add_theme_constant_override("separation", 24)
	body.add_child(_teams)
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 14)
	body.add_child(bar)
	_hero_btn = ScreenBase.big_button("HERO", "BlueButton", Vector2(220, 70), 24)
	_hero_btn.pressed.connect(func(): Audio.play(&"click"); GameManager.show_screen("res://ui/characters_screen.tscn", {"return_to_room": true}))
	bar.add_child(_hero_btn)
	var sw := ScreenBase.big_button("⇄ TEAM", "DarkButton", Vector2(170, 70), 24)
	sw.pressed.connect(func(): Audio.play(&"click"); Lobby.set_team(1 - _my_team()))
	bar.add_child(sw)
	_bots = CheckButton.new()
	_bots.text = "FILL WITH BOTS"
	_bots.add_theme_font_override("font", UiTheme.display_font())
	_bots.add_theme_font_size_override("font_size", 18)
	_bots.toggled.connect(func(on): Lobby.set_fill_bots(on))
	bar.add_child(_bots)
	_ready_btn = ScreenBase.big_button("READY", "GreenButton", Vector2(200, 70), 26)
	_ready_btn.pressed.connect(func(): Audio.play(&"click"); Lobby.set_ready(not _my_ready()))
	bar.add_child(_ready_btn)
	_start_btn = ScreenBase.big_button("START MATCH", "", Vector2(260, 70), 26)
	_start_btn.pressed.connect(func(): Audio.play(&"go"); Lobby.start())
	bar.add_child(_start_btn)
	_status = UiTheme.label("", 18, UiTheme.MUTED, false, 5)
	body.add_child(_status)
	Lobby.state_changed.connect(_render)
	Lobby.kicked.connect(_on_kicked)
	Net.disconnected.connect(_on_disconnected)
	if not Lobby.state.is_empty():
		_render(Lobby.state)
	else:
		_status.text = "Joining room..."


func _exit_tree() -> void:
	if Lobby.state_changed.is_connected(_render):
		Lobby.state_changed.disconnect(_render)
		Lobby.kicked.disconnect(_on_kicked)
		Net.disconnected.disconnect(_on_disconnected)


func _on_back() -> void:
	Net.close()
	Lobby.close_room()
	GameManager.show_screen("res://ui/play_screen.tscn")


func _on_kicked(reason: String) -> void:
	GameManager.show_screen("res://ui/play_screen.tscn")


func _on_disconnected() -> void:
	Lobby.close_room()
	GameManager.show_screen("res://ui/play_screen.tscn")


func _me() -> Dictionary:
	for p in Lobby.state.get("players", []):
		if p.id == Net.my_id():
			return p
	return {}


func _my_team() -> int:
	return _me().get("team", 0)


func _my_ready() -> bool:
	return _me().get("ready", false)


func _render(s: Dictionary) -> void:
	_code.text = s.get("code", "")
	_ip.text = "(%s)" % Net.host_address if Net.is_server() else ""
	for c in _teams.get_children():
		c.queue_free()
	var host: int = s.get("host", 1)
	for team in 2:
		var col := PanelContainer.new()
		col.theme_type_variation = "CardPanel"
		col.custom_minimum_size = Vector2(440, 300)
		var st := UiTheme.box(Color(Settings.TEAM_DARK[team], 0.6), Settings.TEAM_COLORS[team], 20, 3, 8)
		col.add_theme_stylebox_override("panel", st)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		col.add_child(v)
		v.add_child(UiTheme.label(Settings.TEAM_NAMES[team] + " TEAM", 26, Settings.TEAM_COLORS[team].lightened(0.3), true, 8))
		var members: Array = s.get("players", []).filter(func(p): return p.team == team)
		for i in 3:
			var slot := PanelContainer.new()
			slot.theme_type_variation = "GlassPanel"
			slot.custom_minimum_size = Vector2(0, 62)
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 12)
			slot.add_child(h)
			if i < members.size():
				var p: Dictionary = members[i]
				var hd := Skins.apply(Settings.hero_data(StringName(p.hero)), StringName(p.hero), int(p.get("skin", 0)))
				var por := HUD.Portrait.new()
				por.hero = hd
				por.custom_minimum_size = Vector2(48, 48)
				h.add_child(por)
				var n := UiTheme.label(("★ " if p.id == host else "") + p.name + ("  (you)" if p.id == Net.my_id() else ""), 22, Color.WHITE, true, 6)
				n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(n)
				h.add_child(UiTheme.label(hd.display_name, 18, hd.primary_color.lightened(0.3), true, 5))
				var ready: bool = p.ready
				h.add_child(UiTheme.label("HOST" if p.id == host else ("READY" if ready else "WAIT"), 16, Color("6bffb0") if ready else UiTheme.MUTED, true, 5))
			else:
				var e := UiTheme.label("BOT" if s.get("bots", true) else "open slot", 18, Color(1, 1, 1, 0.35), true, 4)
				e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(e)
			v.add_child(slot)
		_teams.add_child(col)
	var is_host := Net.my_id() == host
	var me := _me()
	_hero_btn.text = "HERO: " + Settings.hero_data(StringName(me.get("hero", "volt"))).display_name
	_ready_btn.visible = not is_host
	_ready_btn.text = "NOT READY" if _my_ready() else "READY"
	_start_btn.visible = is_host
	_bots.disabled = not is_host
	_bots.set_pressed_no_signal(s.get("bots", true))
	var all_ready := true
	for p in s.get("players", []):
		if not p.ready:
			all_ready = false
	_start_btn.disabled = not all_ready
	if s.get("in_match", false):
		_status.text = "Match in progress..."
	elif is_host:
		_status.text = "Share the code. Everyone must be READY." if not all_ready else "All set — start when you like!"
	else:
		_status.text = "Waiting for the host to start..."
