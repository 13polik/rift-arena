extends Control
## RESULTS: animated VICTORY / DEFEAT / DRAW banner, final score, MVP and a stat table.

var result: Dictionary = {}
var my_team := 0


func _ready() -> void:
	theme = UiTheme.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var won: bool = result.get("winner", -1) == my_team
	var draw: bool = result.get("winner", -1) == -1
	var bg := MenuBackground.new()
	bg.tint = Color("2a1f6b") if won else (Color("3a1530") if not draw else Color("1f2240"))
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	margin.add_child(v)
	var title := "DRAW" if draw else ("VICTORY" if won else "DEFEAT")
	var col := Color("c8c8ff") if draw else (Color("ffd23f") if won else Color("ff5a6a"))
	var banner := UiTheme.label(title, 104, col, true, 26)
	banner.pivot_offset = Vector2(600, 60)
	v.add_child(banner)
	banner.scale = Vector2(0.3, 0.3)
	create_tween().tween_property(banner, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var sc: Array = result.get("score", [0, 0])
	var score_row := HBoxContainer.new()
	score_row.alignment = BoxContainer.ALIGNMENT_CENTER
	score_row.add_theme_constant_override("separation", 22)
	score_row.add_child(UiTheme.label(str(sc[my_team]), 64, Settings.TEAM_COLORS[my_team], true, 14))
	score_row.add_child(UiTheme.label("—", 40, UiTheme.MUTED, true, 8))
	score_row.add_child(UiTheme.label(str(sc[1 - my_team]), 64, Settings.TEAM_COLORS[1 - my_team], true, 14))
	v.add_child(score_row)
	var reason: String = result.get("reason", "")
	v.add_child(UiTheme.label("ENERGY GOAL REACHED" if reason == "score" else "TIME UP", 18, UiTheme.MUTED, false, 6))
	# MVP = most energy delivered, then eliminations, then damage
	var players: Array = result.get("players", []).duplicate()
	players.sort_custom(func(a, b): return a.delivered * 1000 + a.kills * 100 + a.damage / 100 > b.delivered * 1000 + b.kills * 100 + b.damage / 100)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 6)
	panel.add_child(grid)
	for hdr in ["PLAYER", "HERO", "ENERGY", "ELIMS", "DEATHS", "DAMAGE", "HEAL"]:
		grid.add_child(UiTheme.label(hdr, 14, UiTheme.MUTED, false, 4))
	var ordered := players.filter(func(p): return p.team == my_team) + players.filter(func(p): return p.team != my_team)
	for p in ordered:
		var tc: Color = Settings.TEAM_COLORS[p.team]
		var star := "★ " if players.size() > 0 and p == players[0] else ""
		var n := UiTheme.label(star + p.name, 19, tc.lightened(0.35), true, 6)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(n)
		grid.add_child(UiTheme.label(p.hero.to_upper(), 17, Color.WHITE, true, 5))
		grid.add_child(UiTheme.label(str(p.delivered), 19, Color("ffd84a"), true, 5))
		grid.add_child(UiTheme.label(str(p.kills), 19, Color.WHITE, true, 5))
		grid.add_child(UiTheme.label(str(p.deaths), 19, Color.WHITE, true, 5))
		grid.add_child(UiTheme.label(str(p.damage), 19, Color.WHITE, true, 5))
		grid.add_child(UiTheme.label(str(p.healing), 19, Color("6bff9a"), true, 5))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	v.add_child(buttons)
	if Net.is_online():
		var back := Button.new()
		back.text = "BACK TO ROOM"
		back.custom_minimum_size = Vector2(280, 72)
		back.pressed.connect(func(): Audio.play(&"click"); GameManager.show_screen("res://ui/room_screen.tscn"))
		buttons.add_child(back)
	else:
		var again := Button.new()
		again.text = "PLAY AGAIN"
		again.custom_minimum_size = Vector2(260, 72)
		again.pressed.connect(func(): Audio.play(&"click"); GameManager.start_practice(Settings.hero))
		buttons.add_child(again)
	var home := Button.new()
	home.text = "HOME"
	home.theme_type_variation = "DarkButton"
	home.custom_minimum_size = Vector2(200, 72)
	home.pressed.connect(func(): Audio.play(&"click"); GameManager.leave_match())
	buttons.add_child(home)
	# progression reward (once per match)
	var me := {}
	for p in players:
		if not p.bot and (p.id == Net.my_id() or not Net.is_online()):
			me = p
	if not me.is_empty() and not result.get("rewarded", false):
		result["rewarded"] = true
		var c := Skins.reward(won, draw, me.delivered, me.kills)
		var reward := UiTheme.label("+%d ◆ RIFT COINS" % c, 26, Color("ffd84a"), true, 8)
		v.add_child(reward)
		v.move_child(reward, 3)
	Audio.play(&"victory" if won else &"defeat", -6.0)
	if Net.is_server() and Net.is_online():
		Lobby.match_over()
