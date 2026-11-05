class_name HUD
extends CanvasLayer
## In-match HUD: team score + goal progress, timer, core pulse, objective, own HP / energy, minimap,
## kill feed, announcements, countdown, respawn timer, damage vignette, pause menu, touch controls.

var m: Match
var my_team := 0
var touch: TouchControls
var root: Control

var _score_ally: Label
var _score_enemy: Label
var _timer: Label
var _goal: Label
var _bar_ally: ProgressBar
var _bar_enemy: ProgressBar
var _pulse: ProgressBar
var _objective: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _hp_fill: StyleBoxFlat
var _portrait: Control
var _carry: Label
var _feed: VBoxContainer
var _minimap: Minimap
var _center: Label
var _sub: Label
var _announce_t := 0.0
var _vignette: ColorRect
var _vig := 0.0
var _fps: Label
var _pause: Control
var _last_count := -1
var _urgent := false


func setup(match_node: Match, team: int) -> void:
	m = match_node
	my_team = team
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	add_child(root)
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item; uniform float amount = 0.0; void fragment(){ vec2 p = UV * 2.0 - 1.0; float v = smoothstep(0.55, 1.35, length(p * vec2(0.8, 1.0))); COLOR = vec4(0.9, 0.05, 0.12, v * amount); }"
	var sm := ShaderMaterial.new()
	sm.shader = sh
	_vignette.material = sm
	root.add_child(_vignette)
	touch = TouchControls.new()
	root.add_child(touch)
	_build_top()
	_build_self()
	_build_right()
	_build_center()
	_build_pause()
	_fps = UiTheme.label("", 14, Color(1, 1, 1, 0.6), false, 4)
	_fps.position = Vector2(12, 690)
	_fps.visible = Settings.show_fps
	root.add_child(_fps)


func _build_top() -> void:
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-190, 10)
	top.custom_minimum_size = Vector2(380, 0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 4)
	root.add_child(top)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	top.add_child(row)
	_score_ally = _score_box(Settings.TEAM_COLORS[0], row)
	var mid := PanelContainer.new()
	mid.add_theme_stylebox_override("panel", UiTheme.box(Color("0b0e22"), Color(1, 1, 1, 0.15), 0, 0))
	mid.custom_minimum_size = Vector2(110, 64)
	var mv := VBoxContainer.new()
	mv.alignment = BoxContainer.ALIGNMENT_CENTER
	mv.add_theme_constant_override("separation", -6)
	mid.add_child(mv)
	_timer = UiTheme.label("3:30", 30)
	mv.add_child(_timer)
	_goal = UiTheme.label("FIRST TO 14", 12, UiTheme.MUTED, false, 4)
	mv.add_child(_goal)
	row.add_child(mid)
	_score_enemy = _score_box(Settings.TEAM_COLORS[1], row)
	# ally/enemy colors are relative to me: my team always on the left
	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", 6)
	top.add_child(bars)
	_bar_ally = _progress(Settings.TEAM_COLORS[my_team], bars, true)
	_bar_enemy = _progress(Settings.TEAM_COLORS[1 - my_team], bars, false)
	_pulse = _progress(Color("6ff6ff"), top, false)
	_pulse.custom_minimum_size = Vector2(180, 8)
	_pulse.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_objective = UiTheme.label("", 17, Color("8ff8e0"), false, 6)
	top.add_child(_objective)
	(_score_ally.get_parent() as PanelContainer).add_theme_stylebox_override("panel", _score_style(Settings.TEAM_COLORS[my_team], true))
	(_score_enemy.get_parent() as PanelContainer).add_theme_stylebox_override("panel", _score_style(Settings.TEAM_COLORS[1 - my_team], false))
	_goal.text = "FIRST TO %d" % m.mode_data.win_score


func _score_style(c: Color, left: bool) -> StyleBoxFlat:
	var s := UiTheme.box(c, c.darkened(0.45), 0, 0)
	s.border_width_bottom = 6
	s.border_color = c.darkened(0.45)
	if left:
		s.corner_radius_top_left = 18
		s.corner_radius_bottom_left = 18
	else:
		s.corner_radius_top_right = 18
		s.corner_radius_bottom_right = 18
	return s


func _score_box(c: Color, parent: Control) -> Label:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(96, 64)
	var l := UiTheme.label("0", 40)
	l.pivot_offset = Vector2(30, 30)
	p.add_child(l)
	parent.add_child(p)
	return l


func _progress(c: Color, parent: Control, rtl: bool) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(186, 10)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.max_value = 1.0
	b.fill_mode = ProgressBar.FILL_END_TO_BEGIN if rtl else ProgressBar.FILL_BEGIN_TO_END
	var f := UiTheme.box(c, Color(0, 0, 0, 0), 6)
	f.content_margin_left = 0
	f.content_margin_right = 0
	b.add_theme_stylebox_override("fill", f)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
	return b


func _build_self() -> void:
	var me := m.local_hero()
	var box := HBoxContainer.new()
	box.position = Vector2(16, 12)
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	_portrait = Portrait.new()
	_portrait.hero = me.data if me else Settings.hero_data(&"volt")
	_portrait.custom_minimum_size = Vector2(64, 64)
	box.add_child(_portrait)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	box.add_child(col)
	var name_l := UiTheme.label(me.player_name if me else "", 18, Color.WHITE, true, 6)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(name_l)
	var hp_wrap := Control.new()
	hp_wrap.custom_minimum_size = Vector2(230, 22)
	col.add_child(hp_wrap)
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.max_value = 1.0
	_hp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_fill = UiTheme.box(Color("4dff8a"), Color(0, 0, 0, 0), 10)
	_hp_fill.content_margin_left = 0
	_hp_fill.content_margin_right = 0
	_hp_bar.add_theme_stylebox_override("fill", _hp_fill)
	hp_wrap.add_child(_hp_bar)
	_hp_label = UiTheme.label("", 15, Color.WHITE, true, 5)
	_hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_wrap.add_child(_hp_label)
	_carry = UiTheme.label("", 18, Color("ffd84a"), true, 6)
	_carry.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(_carry)
	var pause_btn := Button.new()
	pause_btn.text = "II"
	pause_btn.theme_type_variation = "DarkButton"
	pause_btn.custom_minimum_size = Vector2(54, 50)
	pause_btn.add_theme_font_size_override("font_size", 20)
	pause_btn.pressed.connect(func(): _pause.visible = true; Audio.play(&"click"))
	box.add_child(pause_btn)


func _build_right() -> void:
	_minimap = Minimap.new()
	_minimap.m = m
	_minimap.my_team = my_team
	_minimap.custom_minimum_size = Vector2(200, 126)
	_minimap.size = Vector2(200, 126)
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap.position = Vector2(-216, 12)
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_minimap)
	_feed = VBoxContainer.new()
	_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_feed.position = Vector2(-330, 148)
	_feed.custom_minimum_size = Vector2(314, 0)
	_feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_feed)


func _build_center() -> void:
	_center = UiTheme.label("", 96, Color("ffd23f"), true, 22)
	_center.set_anchors_preset(Control.PRESET_CENTER)
	_center.position = Vector2(-400, -190)
	_center.size = Vector2(800, 140)
	_center.pivot_offset = Vector2(400, 70)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_center)
	_sub = UiTheme.label("", 26, Color.WHITE, true, 8)
	_sub.set_anchors_preset(Control.PRESET_CENTER)
	_sub.position = Vector2(-400, -60)
	_sub.size = Vector2(800, 40)
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_sub)


func _build_pause() -> void:
	_pause = ColorRect.new()
	(_pause as ColorRect).color = Color(0.02, 0.02, 0.08, 0.7)
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	root.add_child(_pause)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-200, -150)
	panel.custom_minimum_size = Vector2(400, 300)
	_pause.add_child(panel)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	v.add_child(UiTheme.label("PAUSED", 40))
	var resume := Button.new()
	resume.text = "RESUME"
	resume.pressed.connect(func(): _pause.visible = false; Audio.play(&"click"))
	v.add_child(resume)
	var leave := Button.new()
	leave.text = "LEAVE MATCH"
	leave.theme_type_variation = "RedButton"
	leave.pressed.connect(func(): Audio.play(&"click"); GameManager.leave_match())
	v.add_child(leave)
	var note := UiTheme.label("The match keeps running online.", 14, UiTheme.MUTED, false, 4)
	v.add_child(note)


# ----------------------------------------------------------------- live updates
func refresh(delta: float) -> void:
	Prof.begin("hud")
	var me := m.local_hero()
	var sc: Array = m.mode.score
	var left: float = m.mode.time_left() if m.is_server else m.get_meta(&"time_left", m.mode_data.duration)
	var pulse_in: float = m.mode.pulse_in() if m.is_server else m.get_meta(&"pulse_in", 0.0)
	_score_ally.text = str(sc[my_team])
	_score_enemy.text = str(sc[1 - my_team])
	_bar_ally.value = float(sc[my_team]) / m.mode_data.win_score
	_bar_enemy.value = float(sc[1 - my_team]) / m.mode_data.win_score
	var secs := int(ceil(left))
	_timer.text = "%d:%02d" % [secs / 60, secs % 60]
	var urgent := secs <= 30 and m.phase == Match.Phase.PLAYING
	if urgent != _urgent:
		_urgent = urgent
		_timer.add_theme_color_override("font_color", Color("ff6b6b") if urgent else Color.WHITE)
	_pulse.value = 1.0 - pulse_in / m.mode_data.pulse_interval
	if me:
		_hp_bar.value = me.hp_frac()
		_hp_label.text = "%d" % int(me.hp)
		var hp_col := Color("4dff8a") if me.hp_frac() > 0.5 else (Color("ffd23f") if me.hp_frac() > 0.25 else Color("ff4d5e"))
		_hp_fill.bg_color = hp_col
		_carry.text = ("⚡ %d / %d ENERGY" % [me.carried, m.mode_data.max_carry]) if me.carried > 0 else ""
		_objective.text = _objective_text(me)
	# countdown / respawn
	if m.phase == Match.Phase.COUNTDOWN:
		var c := int(ceil(m.play_start - m.time))
		if c != _last_count and c > 0:
			_last_count = c
			_show_center(str(c), Color.WHITE, 0.9)
			Audio.play(&"countdown")
		_sub.text = "COLLECT ENERGY · DELIVER IT TO YOUR UPLINK"
	elif me and not me.alive:
		var rs: float = maxf(0.0, me.respawn_at - m.time) if m.is_server else me.get_meta(&"respawn_in", 0.0)
		_sub.text = "RESPAWNING IN %d" % int(ceil(rs))
	elif _announce_t <= 0.0:
		_sub.text = ""
	_announce_t -= delta
	if _announce_t <= 0.0 and m.phase != Match.Phase.COUNTDOWN:
		_center.modulate.a = maxf(0.0, _center.modulate.a - delta * 3.0)
	_vig = maxf(0.0, _vig - delta * 2.2)
	var low := 0.0
	if me and me.alive and me.hp_frac() < 0.3:
		low = 0.25 + 0.15 * sin(Time.get_ticks_msec() / 160.0)
	(_vignette.material as ShaderMaterial).set_shader_parameter("amount", maxf(_vig, low))
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
	Prof.end("hud")


func _objective_text(me: Hero) -> String:
	if m.phase == Match.Phase.ENDED:
		return ""
	if not me.alive:
		return "You were eliminated"
	if me.carried >= m.mode_data.max_carry:
		return "FULL! Deliver your energy to the UPLINK"
	if me.carried > 0:
		var t := "Bring %d energy home to your UPLINK" % me.carried
		if me.carried >= m.mode_data.reveal_carry:
			t += " · you are glowing!"
		return t
	if m.field_has_shards():
		return "Grab Rift Energy near the core"
	return "Core pulse incoming — hold the middle"


func _show_center(text: String, color: Color, dur := 1.2) -> void:
	_center.text = text
	_center.add_theme_color_override("font_color", color)
	_center.modulate.a = 1.0
	_center.scale = Vector2(1.6, 1.6)
	var tw := create_tween()
	tw.tween_property(_center, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_announce_t = dur


func announce(text: String, color: Color, dur := 1.3) -> void:
	_show_center(text, color, dur)


func damage_flash() -> void:
	_vig = 0.8


func score_pop(team: int) -> void:
	var l := _score_ally if team == my_team else _score_enemy
	l.scale = Vector2(1.6, 1.6)
	create_tween().tween_property(l, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func kill_feed(killer: Hero, victim: Hero) -> void:
	if victim == null:
		return
	var row := PanelContainer.new()
	row.theme_type_variation = "GlassPanel"
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(h)
	var kc := Settings.TEAM_COLORS[killer.team] if killer else UiTheme.MUTED
	var a := UiTheme.label(killer.player_name if killer else "", 16, kc.lightened(0.3), true, 5)
	var x := UiTheme.label("  ✖  ", 16, Color("ffd23f"), true, 5)
	var b := UiTheme.label(victim.player_name, 16, Settings.TEAM_COLORS[victim.team].lightened(0.3), true, 5)
	h.add_child(a)
	h.add_child(x)
	h.add_child(b)
	_feed.add_child(row)
	while _feed.get_child_count() > 4:
		_feed.get_child(0).queue_free()
		_feed.remove_child(_feed.get_child(0))
	# bound to the row itself: the connection disappears automatically if the HUD is freed first
	get_tree().create_timer(4.5).timeout.connect(row.queue_free)


## Small round portrait drawn from hero colors (no textures).
class Portrait extends Control:
	var hero: HeroData
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.35))
		draw_circle(c, r, hero.secondary_color)
		draw_circle(c, r - 4, hero.primary_color)
		draw_circle(c + Vector2(0, 4), r * 0.55, hero.skin_color)
		draw_rect(Rect2(c + Vector2(-r * 0.45, -r * 0.05), Vector2(r * 0.9, r * 0.22)), hero.accent_color)
		draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.8), 3.0, true)
