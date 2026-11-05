extends Node
# Generates app icons (PNG) from assets/icon.svg and saves the UI Theme as resources/ui/rift_theme.tres.
# Usage: tools/run.sh tools/build_assets.tscn
func _ready() -> void:
	var svg := FileAccess.get_file_as_string("res://assets/icon.svg")
	for size in [192, 1024, 180, 120, 152, 167]:
		var img := Image.new()
		img.load_svg_from_string(svg, size / 128.0)
		img.save_png("res://assets/icon_%d.png" % size)
	# Android adaptive icon: foreground (gem only, padded to the 66% safe zone) + background
	var fg_svg := svg.replace('<rect width="128" height="128" rx="28" fill="url(#g)"/>', "")
	var fg := Image.new()
	fg.load_svg_from_string(fg_svg, 432.0 / 128.0 * 0.62)
	var canvas := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	canvas.blit_rect(fg, Rect2i(Vector2i.ZERO, fg.get_size()), Vector2i((432 - fg.get_width()) / 2, (432 - fg.get_height()) / 2))
	canvas.save_png("res://assets/icon_fg_432.png")
	var bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	for y in 432:
		var c := Color("2a1f6b").lerp(Color("0d1024"), y / 432.0)
		for x in 432:
			bg.set_pixel(x, y, c)
	bg.save_png("res://assets/icon_bg_432.png")
	var err := ResourceSaver.save(UiTheme.make(), "res://resources/ui/rift_theme.tres")
	print("ASSETS_OK theme_err=", err)
	get_tree().quit()
