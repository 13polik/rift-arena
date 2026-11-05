extends ScreenBase
## CHARACTER SELECT: big animated 3D model (tap it!), role, stat bars, attack / ability / super cards, SELECT.

var return_to_room := false
var _id: StringName
var _show: HeroShowcase
var _info: VBoxContainer
var _tabs: HBoxContainer
var _select: Button


func _init() -> void:
	title_text = "CHARACTERS"


func build() -> void:
	_id = Settings.hero
	_tabs = HBoxContainer.new()
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	_tabs.add_theme_constant_override("separation", 12)
	header.add_child(_tabs)
	header.move_child(_tabs, header.get_child_count() - 2)
	for id in Settings.HEROES:
		var hd := Settings.hero_data(id)
		var b := ScreenBase.big_button(hd.display_name, "DarkButton", Vector2(150, 58), 22)
		b.pressed.connect(func(): Audio.play(&"click"); _show_hero(id))
		b.set_meta(&"id", id)
		_tabs.add_child(b)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 24)
	body.add_child(row)
	_show = HeroShowcase.new()
	_show.hero_id = _id
	_show.skin = Settings.skin_for(_id)
	_show.custom_minimum_size = Vector2(470, 540)
	row.add_child(_show)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	row.add_child(right)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 8)
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_info)
	_select = ScreenBase.big_button("SELECT", "", Vector2(300, 80), 32)
	_select.size_flags_horizontal = Control.SIZE_SHRINK_END
	_select.pressed.connect(_on_select)
	right.add_child(_select)
	_show_hero(_id)


func _on_back() -> void:
	if return_to_room:
		GameManager.show_screen("res://ui/room_screen.tscn")
	else:
		GameManager.go_home()


func _show_hero(id: StringName) -> void:
	_id = id
	_show.set_hero(id, Settings.skin_for(id))
	for b in _tabs.get_children():
		b.theme_type_variation = "BlueButton" if b.get_meta(&"id") == id else "DarkButton"
	for c in _info.get_children():
		c.queue_free()
	var hd := Skins.apply(Settings.hero_data(id), id, Settings.skin_for(id))
	var name_l := UiTheme.label(hd.display_name, 64, hd.primary_color.lightened(0.15), true, 16)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_info.add_child(name_l)
	var role := UiTheme.label("%s  ·  %s" % [hd.role.to_upper(), hd.weapon.to_upper()], 20, Color("6ff6ff"), true, 6)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_info.add_child(role)
	var desc := UiTheme.label(hd.description, 18, UiTheme.TEXT, false, 4)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(560, 0)
	_info.add_child(desc)
	# stat bars normalized against the roster
	var dps := hd.attack.damage * hd.attack.count * hd.attack.burst_count / hd.attack.cooldown
	_stat("HEALTH", hd.max_hp, 6000.0, str(hd.max_hp), Color("4dff8a"))
	_stat("DAMAGE / SEC", dps, 1300.0, str(int(dps)), Color("ff6b6b"))
	_stat("SPEED", hd.move_speed, 6.0, "%.1f" % hd.move_speed, Color("6ff6ff"))
	_stat("RANGE", hd.attack.range, 11.0, "%.1f m" % hd.attack.range, Color("ffd23f"))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 10)
	_info.add_child(cards)
	cards.add_child(_ability_card("ATTACK", hd.attack, Color("ff5a4e")))
	cards.add_child(_ability_card("ABILITY", hd.ability, Color("4cc3ff")))
	cards.add_child(_ability_card("SUPER", hd.super_ability, Color("ffd23f")))
	_select.text = "SELECTED" if id == Settings.hero else "SELECT"
	_select.disabled = id == Settings.hero


func _stat(label: String, value: float, maxv: float, text: String, color: Color) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l := UiTheme.label(label, 16, UiTheme.MUTED, true, 4)
	l.custom_minimum_size = Vector2(150, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	h.add_child(l)
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = 1.0
	b.custom_minimum_size = Vector2(300, 18)
	b.value = 0.0
	var f := UiTheme.box(color, Color(0, 0, 0, 0), 8)
	f.content_margin_left = 0
	f.content_margin_right = 0
	b.add_theme_stylebox_override("fill", f)
	h.add_child(b)
	create_tween().tween_property(b, "value", clampf(value / maxv, 0.05, 1.0), 0.4).set_trans(Tween.TRANS_CUBIC)
	h.add_child(UiTheme.label(text, 18, Color.WHITE, true, 5))
	_info.add_child(h)


func _ability_card(kind: String, a: AbilityData, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "CardPanel"
	p.custom_minimum_size = Vector2(190, 120)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	v.add_child(UiTheme.label(kind, 14, color, true, 4))
	var n := UiTheme.label(a.display_name, 18, Color.WHITE, true, 5)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(n)
	var info := ""
	match a.kind:
		AbilityData.Kind.PROJECTILE:
			info = "%d dmg × %d" % [a.damage, a.count * a.burst_count]
			if a.homing_turn_rate > 0.0: info += " · homing"
		AbilityData.Kind.MELEE: info = "%d dmg · %d° arc" % [a.damage, a.arc_deg]
		AbilityData.Kind.BLINK: info = "teleport %.1f m" % a.range
		AbilityData.Kind.CHARGE: info = "dash %.0f m · %d dmg" % [a.range, a.damage]
		AbilityData.Kind.ZONE: info = ("slow %d%% · %d dps" % [a.magnitude * 100, a.dps]) if a.zone_effect == &"slow" else ("heal %d/s · %.0fs" % [a.magnitude, a.duration])
		AbilityData.Kind.BLAST_PROJECTILE: info = "%d dmg · %.1f m blast" % [a.damage, a.blast_radius]
		AbilityData.Kind.SHOCKWAVE: info = "%d dmg · %.1f m · slow" % [a.damage, a.range]
	if kind != "SUPER" and a.cooldown > 0.6:
		info += "\n%.1fs cooldown" % a.cooldown
	var t := UiTheme.label(info, 14, UiTheme.MUTED, false, 3)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	return p


func _on_select() -> void:
	Audio.play(&"pickup")
	Settings.hero = _id
	Settings.save()
	if Net.is_online():
		Lobby.set_hero(_id)
	_show_hero(_id)
	_show._visual.play_action(&"super")
