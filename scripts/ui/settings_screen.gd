extends ScreenBase
## SETTINGS: graphics quality LOW / MEDIUM / HIGH, frame-rate cap, FPS counter, music & SFX volume, name.

var _quality_btns: Array[Button] = []
var _fps_btns: Array[Button] = []


func _init() -> void:
	title_text = "SETTINGS"


func build() -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(820, 0)
	body.add_child(panel)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 30)
	g.add_theme_constant_override("v_separation", 22)
	panel.add_child(g)
	g.add_child(_lbl("GRAPHICS"))
	var q := HBoxContainer.new()
	q.add_theme_constant_override("separation", 10)
	for i in 3:
		var b := ScreenBase.big_button(["LOW", "MEDIUM", "HIGH"][i], "DarkButton", Vector2(160, 62), 22)
		b.pressed.connect(func(): Audio.play(&"click"); Settings.set_quality(i); _sync())
		q.add_child(b)
		_quality_btns.append(b)
	g.add_child(q)
	g.add_child(_lbl("FRAME RATE"))
	var f := HBoxContainer.new()
	f.add_theme_constant_override("separation", 10)
	var caps := [30, 60, 0]
	for i in 3:
		var b := ScreenBase.big_button(["30", "60", "MAX"][i], "DarkButton", Vector2(160, 62), 22)
		var cap: int = caps[i]
		b.pressed.connect(func(): Audio.play(&"click"); Settings.fps_cap = cap; Settings.apply_engine_settings(); Settings.save(); _sync())
		f.add_child(b)
		_fps_btns.append(b)
	g.add_child(f)
	g.add_child(_lbl("SHOW FPS"))
	var show := CheckButton.new()
	show.button_pressed = Settings.show_fps
	show.toggled.connect(func(on): Settings.show_fps = on; Settings.save())
	g.add_child(show)
	g.add_child(_lbl("MUSIC"))
	g.add_child(_slider(Settings.music_volume, func(v): Settings.music_volume = v; Audio.apply_volumes(); Settings.save()))
	g.add_child(_lbl("SOUND FX"))
	g.add_child(_slider(Settings.sfx_volume, func(v): Settings.sfx_volume = v; Audio.apply_volumes(); Settings.save(); Audio.play(&"hit", -6.0)))
	g.add_child(_lbl("ONLINE SERVER"))
	var srv := LineEdit.new()
	srv.text = Settings.online_server
	srv.placeholder_text = "wss://your-server"
	srv.custom_minimum_size = Vector2(500, 52)
	srv.add_theme_font_size_override("font_size", 18)
	srv.text_changed.connect(func(t): Settings.online_server = t.strip_edges(); Settings.save())
	g.add_child(srv)
	var note := UiTheme.label("LOW: no shadows/lights, 70% render scale · MEDIUM: glow + FXAA · HIGH: shadows, lamps, MSAA", 14, UiTheme.MUTED, false, 4)
	body.add_child(note)
	_sync()


func _lbl(t: String) -> Label:
	var l := UiTheme.label(t, 22, Color.WHITE, true, 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.custom_minimum_size = Vector2(220, 0)
	return l


func _slider(value: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(500, 40)
	s.value_changed.connect(cb)
	return s


func _sync() -> void:
	for i in _quality_btns.size():
		_quality_btns[i].theme_type_variation = "BlueButton" if Settings.quality == i else "DarkButton"
	var caps := [30, 60, 0]
	for i in _fps_btns.size():
		_fps_btns[i].theme_type_variation = "BlueButton" if Settings.fps_cap == caps[i] else "DarkButton"
