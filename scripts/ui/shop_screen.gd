extends ScreenBase
## SHOP: buy and equip hero skins with Rift Coins (earned every match). Live 3D preview of the selected skin.

var _show: HeroShowcase
var _list: VBoxContainer
var _hero: StringName
var _skin := 0


func _init() -> void:
	title_text = "SHOP"


func build() -> void:
	_hero = Settings.hero
	_skin = Settings.skin_for(_hero)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 24)
	body.add_child(row)
	_show = HeroShowcase.new()
	_show.hero_id = _hero
	_show.skin = _skin
	_show.custom_minimum_size = Vector2(420, 520)
	row.add_child(_show)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	_render()


func _render() -> void:
	for c in _list.get_children():
		c.queue_free()
	refresh_coins()
	for id in Settings.HEROES:
		var hd := Settings.hero_data(id)
		var h := UiTheme.label(hd.display_name, 26, hd.primary_color.lightened(0.2), true, 8)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_list.add_child(h)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_list.add_child(row)
		var cat: Array = Skins.CATALOG[id]
		for i in cat.size():
			row.add_child(_skin_card(id, i, cat[i]))


func _skin_card(id: StringName, i: int, s: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "CardPanel"
	p.custom_minimum_size = Vector2(200, 150)
	if id == _hero and i == _skin:
		p.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_2, Color("ffd23f"), 20, 4, 8))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var swatch := HUD.Portrait.new()
	swatch.hero = Skins.apply(Settings.hero_data(id), id, i)
	swatch.custom_minimum_size = Vector2(56, 56)
	swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(swatch)
	v.add_child(UiTheme.label(s.name, 17, Color.WHITE, true, 5))
	var b := Button.new()
	b.add_theme_font_size_override("font_size", 18)
	b.custom_minimum_size = Vector2(170, 46)
	var owned := Skins.owned(id, i)
	var equipped := Settings.skin_for(id) == i
	if equipped:
		b.text = "EQUIPPED"
		b.disabled = true
	elif owned:
		b.text = "EQUIP"
		b.theme_type_variation = "BlueButton"
	else:
		b.text = "◆ %d" % s.price
		b.theme_type_variation = "GreenButton"
		b.disabled = Settings.coins < s.price
	b.pressed.connect(func(): _buy_or_equip(id, i))
	v.add_child(b)
	# tapping the card previews it
	p.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			_preview(id, i))
	return p


func _preview(id: StringName, i: int) -> void:
	_hero = id
	_skin = i
	_show.set_hero(id, i)
	_render()


func _buy_or_equip(id: StringName, i: int) -> void:
	if not Skins.owned(id, i):
		if not Skins.buy(id, i):
			return
		Audio.play(&"deposit")
	else:
		Audio.play(&"click")
	Settings.equipped[String(id)] = i
	Settings.save()
	_preview(id, i)
