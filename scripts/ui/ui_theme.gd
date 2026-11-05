class_name UiTheme
extends RefCounted
## Builds the game's Theme resource (fonts, buttons, panels, bars) in code so it ships with zero assets,
## and saves it to resources/ui/rift_theme.tres (tools/build_theme) for use in the editor.

const INK := Color("0d1024")
const PANEL := Color("171c3a")
const PANEL_2 := Color("222a52")
const LINE := Color("3a4690")
const GOLD := Color("ffd23f")
const CYAN := Color("3ef0c4")
const TEXT := Color("eef1ff")
const MUTED := Color("9aa3d6")

static var _display: Font
static var _body: Font


## Chunky display font for titles / numbers (system black weight, falls back gracefully on mobile).
static func display_font() -> Font:
	if _display == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Arial Black", "Impact", "sans-serif-black", "Roboto Black", "Helvetica Neue", "sans-serif"])
		sf.font_weight = 900
		sf.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_display = sf
	return _display


static func body_font() -> Font:
	if _body == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Segoe UI", "Roboto", "Helvetica Neue", "sans-serif"])
		sf.font_weight = 800
		_body = sf
	return _body


static func box(bg: Color, border := Color(0, 0, 0, 0), radius := 18, bw := 0, shadow := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.6)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


## Chunky 3D-looking button style: colored face + darker bottom edge.
static func button_box(face: Color, edge: Color, pressed := false) -> StyleBoxFlat:
	var s := box(face, face.lightened(0.35), 16, 2)
	s.border_width_bottom = 2 if pressed else 7
	s.border_color = edge
	s.expand_margin_bottom = 0
	if pressed:
		s.content_margin_top = 14
	return s


static func make() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 22
	# Label
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0.03, 0.03, 0.1))
	t.set_constant("outline_size", "Label", 6)
	# Button (gold primary)
	t.set_stylebox("normal", "Button", button_box(Color("ffc61a"), Color("b06a00")))
	t.set_stylebox("hover", "Button", button_box(Color("ffd84a"), Color("b06a00")))
	t.set_stylebox("pressed", "Button", button_box(Color("f0b400"), Color("b06a00"), true))
	t.set_stylebox("disabled", "Button", button_box(Color("6b6550"), Color("3b3626")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", display_font())
	t.set_font_size("font_size", "Button", 26)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", Color("2a1500"))
	t.set_color("font_disabled_color", "Button", Color("2a2a2a"))
	# Variations
	_variant(t, "BlueButton", Color("4a7dff"), Color("1f3a9e"), TEXT)
	_variant(t, "GreenButton", Color("2fe0a5"), Color("0b7a5a"), Color("05261b"))
	_variant(t, "DarkButton", Color("2b3466"), Color("141a3d"), TEXT)
	_variant(t, "RedButton", Color("ff5a6a"), Color("9e1f33"), TEXT)
	# Panels
	t.set_stylebox("panel", "PanelContainer", box(Color(PANEL, 0.94), LINE, 22, 3, 10))
	t.set_stylebox("panel", "Panel", box(Color(PANEL, 0.94), LINE, 22, 3, 10))
	t.set_type_variation("CardPanel", "PanelContainer")
	t.set_stylebox("panel", "CardPanel", box(PANEL_2, LINE, 20, 3, 8))
	t.set_type_variation("GlassPanel", "PanelContainer")
	t.set_stylebox("panel", "GlassPanel", box(Color(0.04, 0.05, 0.14, 0.6), Color(1, 1, 1, 0.12), 16, 2))
	# LineEdit
	t.set_stylebox("normal", "LineEdit", box(Color("0b0e22"), LINE, 14, 3))
	t.set_stylebox("focus", "LineEdit", box(Color("0b0e22"), CYAN, 14, 3))
	t.set_font("font", "LineEdit", display_font())
	t.set_font_size("font_size", "LineEdit", 26)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	# ProgressBar
	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.15), 10, 2))
	var fill := box(Color("4dff8a"), Color(0, 0, 0, 0), 10)
	fill.content_margin_left = 0
	fill.content_margin_right = 0
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_constant("outline_size", "ProgressBar", 0)
	# Title labels
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", display_font())
	t.set_font_size("font_size", "TitleLabel", 54)
	t.set_constant("outline_size", "TitleLabel", 14)
	t.set_type_variation("HeaderLabel", "Label")
	t.set_font("font", "HeaderLabel", display_font())
	t.set_font_size("font_size", "HeaderLabel", 30)
	t.set_constant("outline_size", "HeaderLabel", 10)
	t.set_type_variation("SmallLabel", "Label")
	t.set_font_size("font_size", "SmallLabel", 16)
	t.set_color("font_color", "SmallLabel", MUTED)
	# CheckButton: plain text + switch (must not inherit the chunky Button boxes)
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		t.set_stylebox(st, "CheckButton", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, "CheckButton", TEXT)
	t.set_stylebox("slider", "HSlider", box(Color(0, 0, 0, 0.5), Color(0, 0, 0, 0), 6))
	t.set_stylebox("grabber_area", "HSlider", box(CYAN, Color(0, 0, 0, 0), 6))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(CYAN.lightened(0.2), Color(0, 0, 0, 0), 6))
	return t


static func _variant(t: Theme, name: String, face: Color, edge: Color, font: Color) -> void:
	t.set_type_variation(name, "Button")
	t.set_stylebox("normal", name, button_box(face, edge))
	t.set_stylebox("hover", name, button_box(face.lightened(0.1), edge))
	t.set_stylebox("pressed", name, button_box(face.darkened(0.08), edge, true))
	t.set_stylebox("disabled", name, button_box(face.darkened(0.5), edge.darkened(0.5)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, name, font)


## Big outlined label helper for HUD / menus.
static func label(text: String, size: int, color := TEXT, display := true, outline := 10) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", display_font() if display else body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.1))
	l.add_theme_constant_override("outline_size", outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
