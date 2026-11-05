extends ScreenBase
## HOME: logo, selected hero on a pedestal, PLAY, CHARACTERS, SHOP, SETTINGS, player profile.


func _init() -> void:
	show_back = false


func build() -> void:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 20)
	body.add_child(row)
	# left: logo + profile
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)
	var logo := UiTheme.label("RIFT\nARENA", 104, Color("ffd23f"), true, 26)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	logo.add_theme_constant_override("line_spacing", -34)
	left.add_child(logo)
	var tag := UiTheme.label("3 V 3  ·  RIFT CORE", 24, Color("6ff6ff"), true, 8)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(tag)
	var profile := PanelContainer.new()
	profile.theme_type_variation = "GlassPanel"
	profile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 12)
	profile.add_child(ph)
	var name_edit := LineEdit.new()
	name_edit.text = Settings.player_name
	name_edit.max_length = 14
	name_edit.custom_minimum_size = Vector2(250, 54)
	name_edit.text_changed.connect(func(t): Settings.player_name = t.strip_edges() if t.strip_edges() != "" else Settings.player_name; Settings.save())
	ph.add_child(name_edit)
	var stats := UiTheme.label("%d WINS · %d MATCHES" % [Settings.wins, Settings.matches_played], 16, UiTheme.MUTED, false, 4)
	ph.add_child(stats)
	left.add_child(profile)
	# center: hero showcase
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(mid)
	var show := HeroShowcase.new()
	show.hero_id = Settings.hero
	show.skin = Settings.skin_for(Settings.hero)
	show.custom_minimum_size = Vector2(380, 470)
	mid.add_child(show)
	var hd := Settings.hero_data(Settings.hero)
	var hn := UiTheme.label(hd.display_name, 40, hd.primary_color.lightened(0.2), true, 12)
	mid.add_child(hn)
	var hr := UiTheme.label(hd.role.to_upper(), 16, UiTheme.MUTED, false, 4)
	mid.add_child(hr)
	# right: actions
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 16)
	row.add_child(right)
	var play := ScreenBase.big_button("PLAY", "", Vector2(330, 118), 52)
	play.pressed.connect(func(): Audio.play(&"click"); GameManager.show_screen("res://ui/play_screen.tscn"))
	right.add_child(play)
	var chars := ScreenBase.big_button("CHARACTERS", "BlueButton", Vector2(330, 74), 26)
	chars.pressed.connect(func(): Audio.play(&"click"); GameManager.show_screen("res://ui/characters_screen.tscn"))
	right.add_child(chars)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 12)
	right.add_child(r2)
	var shop := ScreenBase.big_button("SHOP", "GreenButton", Vector2(159, 70), 24)
	shop.pressed.connect(func(): Audio.play(&"click"); GameManager.show_screen("res://ui/shop_screen.tscn"))
	r2.add_child(shop)
	var settings := ScreenBase.big_button("SETTINGS", "DarkButton", Vector2(159, 70), 22)
	settings.pressed.connect(func(): Audio.play(&"click"); GameManager.show_screen("res://ui/settings_screen.tscn"))
	r2.add_child(settings)
	# gentle idle bounce on PLAY
	var tw := create_tween().set_loops()
	tw.tween_property(play, "scale", Vector2(1.04, 1.04), 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(play, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
