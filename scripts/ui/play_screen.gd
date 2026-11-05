extends ScreenBase
## PLAY: practice vs bots (offline), CREATE ROOM (host on this device), JOIN ROOM (room code or ip).

var _status: Label
var _code: LineEdit


func _init() -> void:
	title_text = "PLAY"


func build() -> void:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	body.add_child(row)
	row.add_child(_card("ONLINE", "Play with friends anywhere over the internet.", Color("ff6bd5"), "PLAY ONLINE", "RedButton", _online))
	row.add_child(_card("PRACTICE", "3v3 with bots.\nOffline, instant.", Color("ffd23f"), "START", "", func(): GameManager.start_practice(Settings.hero)))
	row.add_child(_card("CREATE ROOM", "Host on this device.\nSame Wi-Fi only.", Color("2fe0a5"), "CREATE", "GreenButton", _create))
	var join := _card("JOIN ROOM", "Enter the ROOM CODE\n(or host IP).", Color("4a7dff"), "JOIN", "BlueButton", _join)
	_code = LineEdit.new()
	_code.placeholder_text = "ROOM CODE"
	_code.max_length = 21
	_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code.custom_minimum_size = Vector2(240, 60)
	_code.text = Settings.last_address
	_code.text_submitted.connect(func(_t): _join())
	(join.get_child(0) as VBoxContainer).add_child(_code)
	(join.get_child(0) as VBoxContainer).move_child(_code, 2)
	row.add_child(join)
	_status = UiTheme.label("", 20, UiTheme.MUTED, false, 6)
	body.add_child(_status)
	Net.connection_failed.connect(_on_failed)
	Net.connected.connect(_on_connected)


func _exit_tree() -> void:
	if Net.connection_failed.is_connected(_on_failed):
		Net.connection_failed.disconnect(_on_failed)
		Net.connected.disconnect(_on_connected)


func _card(title: String, desc: String, color: Color, btn: String, variation: String, cb: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "CardPanel"
	p.custom_minimum_size = Vector2(285, 380)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	p.add_child(v)
	v.add_child(UiTheme.label(title, 32, color, true, 10))
	var d := UiTheme.label(desc, 18, UiTheme.TEXT, false, 4)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(240, 0)
	v.add_child(d)
	var b := ScreenBase.big_button(btn, variation, Vector2(240, 76), 24)
	b.pressed.connect(func(): Audio.play(&"click"); cb.call())
	v.add_child(b)
	return p


func _online() -> void:
	var url := Settings.online_server
	if url.is_empty():
		_set_status("No online server configured (SETTINGS > ONLINE SERVER)", true)
		return
	var err := Net.join_online(url)
	if err != OK:
		_set_status("Cannot connect (%s)" % error_string(err), true)
		return
	_set_status("Connecting to the online server... (the first connection can take up to a minute)", false)


func _create() -> void:
	var err := Net.host()
	if err != OK:
		_set_status("Could not open a room (%s)" % error_string(err), true)
		return
	Lobby.open_room(true)
	GameManager.show_screen("res://ui/room_screen.tscn")


func _join() -> void:
	var code := _code.text.strip_edges()
	if code.is_empty():
		_set_status("Enter the room code first", true)
		return
	Settings.last_address = code
	Settings.save()
	var err := Net.join(code)
	if err != OK:
		_set_status("Invalid room code" if err == ERR_INVALID_PARAMETER else "Connection error (%s)" % error_string(err), true)
		return
	_set_status("Connecting...", false)


func _on_connected() -> void:
	Lobby.request_join()
	GameManager.show_screen("res://ui/room_screen.tscn")


func _on_failed(reason: String) -> void:
	_set_status(reason, true)


func _set_status(t: String, err: bool) -> void:
	_status.text = t
	_status.add_theme_color_override("font_color", Color("ff6b7a") if err else UiTheme.MUTED)
