class_name ScreenBase
extends Control
## Common menu-screen frame: animated background, safe-area margins (notch / Dynamic Island), header with
## back button + title + coin counter. Subclasses fill `body`.

var body: Control
var header: HBoxContainer
var coin_label: Label
var title_text := ""
var show_back := true


func _ready() -> void:
	theme = UiTheme.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackground.new())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe := safe_margins()
	margin.add_theme_constant_override("margin_left", int(maxf(24.0, safe.x)))
	margin.add_theme_constant_override("margin_right", int(maxf(24.0, safe.y)))
	margin.add_theme_constant_override("margin_top", int(maxf(16.0, safe.z)))
	margin.add_theme_constant_override("margin_bottom", int(maxf(16.0, safe.w)))
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)
	header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	v.add_child(header)
	if show_back:
		var back := Button.new()
		back.text = "◀"
		back.theme_type_variation = "DarkButton"
		back.custom_minimum_size = Vector2(70, 60)
		back.pressed.connect(func(): Audio.play(&"click"); _on_back())
		header.add_child(back)
	if title_text != "":
		var t := UiTheme.label(title_text, 40, Color.WHITE, true, 12)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.add_child(t)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var coins := PanelContainer.new()
	coins.theme_type_variation = "GlassPanel"
	coin_label = UiTheme.label("", 24, Color("ffd84a"), true, 8)
	coins.add_child(coin_label)
	header.add_child(coins)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	refresh_coins()
	build()


## Override in subclasses.
func build() -> void:
	pass


func _on_back() -> void:
	GameManager.go_home()


func refresh_coins() -> void:
	coin_label.text = "◆ %d" % Settings.coins


## Safe-area insets in viewport pixels: (left, right, top, bottom).
static func safe_margins() -> Vector4:
	if OS.get_name() in ["Windows", "macOS", "Linux"]:
		return Vector4.ZERO
	var win := Vector2(DisplayServer.window_get_size())
	var sa := DisplayServer.get_display_safe_area()
	if win.x <= 0 or sa.size.x <= 0:
		return Vector4.ZERO
	var vp := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	var k := vp.y / win.y
	return Vector4(sa.position.x * k, (win.x - sa.end.x) * k, sa.position.y * k, (win.y - sa.end.y) * k)


static func big_button(text: String, variation := "", min_size := Vector2(260, 84), font := 30) -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font)
	b.pivot_offset = min_size * 0.5
	b.button_down.connect(func(): b.scale = Vector2(0.96, 0.96))
	b.button_up.connect(func(): b.scale = Vector2.ONE)
	return b
