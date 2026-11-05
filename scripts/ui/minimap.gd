class_name Minimap
extends Control
## Custom-drawn minimap (no textures, no extra viewport). Own base is always on the left.

var m: Match
var my_team := 0
var _static: Control
var _acc := 0.0


func _ready() -> void:
	# walls / bushes / uplinks never change -> draw them once in a child that never redraws
	_static = Control.new()
	_static.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_static.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_static.draw.connect(_draw_static)
	add_child(_static)
	move_child(_static, 0)


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= 0.1:
		_acc = 0.0
		queue_redraw()


func _mp(x: float, z: float) -> Vector2:
	var L := FractureYardLayout
	var flip := 1.0 if my_team == 0 else -1.0
	return Vector2((x * flip + L.HALF_W) * size.x / (L.HALF_W * 2.0), (z * flip + L.HALF_D) * size.y / (L.HALF_D * 2.0))


func _draw_static() -> void:
	if m == null or m.map == null:
		return
	var L := FractureYardLayout
	var W := size.x
	var H := size.y
	_static.draw_style_box(UiTheme.box(Color(0.03, 0.04, 0.12, 0.78), Color(1, 1, 1, 0.18), 12, 2), Rect2(Vector2.ZERO, size))
	_static.draw_rect(Rect2(Vector2(0, 0), Vector2(W * 0.5, H)), Color(Settings.TEAM_COLORS[my_team], 0.08))
	_static.draw_rect(Rect2(Vector2(W * 0.5, 0), Vector2(W * 0.5, H)), Color(Settings.TEAM_COLORS[1 - my_team], 0.08))
	for r in m.map.bush_rects:
		var a := _mp(r.position.x, r.position.y)
		var b := _mp(r.end.x, r.end.y)
		_static.draw_rect(Rect2(a.min(b), (b - a).abs()), Color(0.2, 0.75, 0.45, 0.45))
	for r in m.map.solid_rects:
		var a2 := _mp(r.position.x, r.position.y)
		var b2 := _mp(r.end.x, r.end.y)
		_static.draw_rect(Rect2(a2.min(b2), (b2 - a2).abs()), Color(0.62, 0.66, 1.0, 0.65))
	for t in 2:
		var u := m.map.uplink_pos(t)
		_static.draw_arc(_mp(u.x, u.z), L.UPLINK_RADIUS * W / (L.HALF_W * 2.0), 0, TAU, 24, Settings.TEAM_COLORS[t], 2.0, true)
	_static.draw_circle(_mp(0.0, 0.0), 4.0, Color("6ff6ff"))


func _draw() -> void:
	Prof.begin("minimap")
	if m == null or m.map == null:
		return
	var to_map := func(x: float, z: float) -> Vector2:
		return _mp(x, z)
	if m.view and m.view.field:
		for id in m.view.field._shards:
			var s: Dictionary = m.view.field._shards[id]
			draw_rect(Rect2(to_map.call(s.to.x, s.to.z) - Vector2(2, 2), Vector2(4, 4)), Color("ffd84a"))
	for h: Hero in m.heroes.values():
		if not h.alive or not h.visible:
			continue
		var p: Vector2 = to_map.call(h.position.x, h.position.z)
		var mine := h.id == m.local_id
		var col := Color.WHITE if mine else (Settings.TEAM_COLORS[0] if h.team == my_team else Settings.TEAM_COLORS[1])
		draw_circle(p, 6.0 if mine else 4.5, Color(0, 0, 0, 0.6))
		draw_circle(p, 4.5 if mine else 3.5, col)
		if h.carried > 0:
			draw_arc(p, 7.0, 0, TAU, 12, Color("ffd84a"), 1.5)
	Prof.end("minimap")
