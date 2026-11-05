class_name TouchControls
extends Control
## On-screen mobile controls, fully custom-drawn (no engine buttons), multitouch by touch index.
##   Left 45% of the screen ........ floating MOVE stick (appears under the thumb, dead zone)
##   AIM stick ...................... drag to aim (trajectory preview), release to fire; drag to the rim = hold-fire
##   ATTACK ......................... tap / hold = auto-aim fire (aim assist picks the best target)
##   ABILITY / SUPER ................ tap = quick-cast (auto-aim); drag = manual aim + preview; release casts;
##                                    drag back onto the button to cancel
## Mouse clicks are treated as touch index 99 so the same UI works on desktop.

signal action(slot: StringName, dir: Vector2, mag: float, manual: bool)   # dir in screen space (y down)

const MOVE_R := 70.0
const DEAD := 0.15

var move := Vector2.ZERO
var aim := Vector2.ZERO          # screen-space unit vector while the aim stick is held
var aim_active := false
var aim_fire := false            # aim stick pulled to the rim -> continuous fire
var attack_held := false
var preview: Dictionary = {}     # {slot, dir, mag} while dragging a skill button

var ability_cd := 0.0            # 0 = ready, 1 = just used
var super_charge := 0.0
var ability_name := "SKILL"
var super_name := "SUPER"
var accent := Color("35d4ff")

var _touch := {}                 # index -> {kind, origin, pos}
var _move_origin := Vector2.ZERO
var _t := 0.0
var _safe := Rect2()
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_font = get_theme_default_font()
	_update_safe()
	get_viewport().size_changed.connect(_update_safe)


func _update_safe() -> void:
	# Convert the OS safe area (notch / Dynamic Island / rounded corners) into viewport coordinates.
	var vp := get_viewport_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	var sa := DisplayServer.get_display_safe_area()
	if win.x <= 0 or sa.size.x <= 0 or OS.get_name() in ["Windows", "macOS", "Linux"]:
		_safe = Rect2(Vector2.ZERO, vp)
	else:
		var k := vp / win
		_safe = Rect2(Vector2(sa.position) * k, Vector2(sa.size) * k).intersection(Rect2(Vector2.ZERO, vp))
	queue_redraw()


# ---------------- layout (computed from the safe area every frame -> any aspect ratio)
func _attack_c() -> Vector2: return _safe.end - Vector2(140, 135)
func _aim_c() -> Vector2: return _safe.end - Vector2(330, 105)
func _super_c() -> Vector2: return _safe.end - Vector2(290, 270)
func _ability_c() -> Vector2: return _safe.end - Vector2(130, 300)
const ATTACK_R := 74.0
const AIM_R := 66.0
const SUPER_R := 54.0
const ABILITY_R := 46.0


func _hit(kind: String, p: Vector2) -> bool:
	match kind:
		"attack": return p.distance_to(_attack_c()) <= ATTACK_R + 14
		"aim": return p.distance_to(_aim_c()) <= AIM_R + 20
		"super": return p.distance_to(_super_c()) <= SUPER_R + 12
		"ability": return p.distance_to(_ability_c()) <= ABILITY_R + 12
	return false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		_touch_event(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_drag_event(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_touch_event(99, event.position, event.pressed, true)
	elif event is InputEventMouseMotion and _touch.has(99):
		_drag_event(99, event.position)


func _touch_event(idx: int, p: Vector2, pressed: bool, is_mouse := false) -> void:
	if pressed:
		var kind := ""
		for k in ["attack", "super", "ability", "aim"]:
			if _hit(k, p):
				kind = k
				break
		if kind == "" and p.x < get_viewport_rect().size.x * 0.45 and not is_mouse:
			kind = "move"
			_move_origin = p
		if kind == "":
			return
		_touch[idx] = {"kind": kind, "origin": p, "pos": p}
		if kind == "attack":
			attack_held = true
		get_viewport().set_input_as_handled()
		queue_redraw()
	elif _touch.has(idx):
		var t: Dictionary = _touch[idx]
		_touch.erase(idx)
		match t.kind:
			"move":
				move = Vector2.ZERO
			"attack":
				attack_held = false
			"aim":
				var v := _vec(_aim_c(), t.pos, AIM_R)
				aim_active = false
				aim_fire = false
				if v.length() > 0.25:
					action.emit(&"attack", v.normalized(), 1.0, true)
			"ability", "super":
				var center := _ability_c() if t.kind == "ability" else _super_c()
				var r := ABILITY_R if t.kind == "ability" else SUPER_R
				var drag: Vector2 = t.pos - center
				preview = {}
				if drag.length() < r * 0.6:
					action.emit(StringName(t.kind), Vector2.ZERO, 1.0, false)      # quick cast
				elif drag.length() > r * 1.1:
					var v2 := _vec(center, t.pos, 130.0)
					action.emit(StringName(t.kind), v2.normalized(), clampf(v2.length(), 0.0, 1.0), true)
				# released back on the button rim -> cancelled
		get_viewport().set_input_as_handled()
		queue_redraw()


func _drag_event(idx: int, p: Vector2) -> void:
	if not _touch.has(idx):
		return
	var t: Dictionary = _touch[idx]
	t.pos = p
	match t.kind:
		"move":
			var v := _vec(_move_origin, p, MOVE_R)
			move = Vector2.ZERO if v.length() < DEAD else v * ((v.length() - DEAD) / (1.0 - DEAD)) / v.length()
		"aim":
			var a := _vec(_aim_c(), p, AIM_R)
			aim_active = a.length() > 0.2
			aim = a.normalized() if aim_active else Vector2.ZERO
			aim_fire = a.length() > 0.92
		"ability", "super":
			var center := _ability_c() if t.kind == "ability" else _super_c()
			var r := ABILITY_R if t.kind == "ability" else SUPER_R
			if (p - center).length() > r * 1.1:
				var v2 := _vec(center, p, 130.0)
				preview = {"slot": StringName(t.kind), "dir": v2.normalized(), "mag": clampf(v2.length(), 0.0, 1.0)}
			else:
				preview = {}
	get_viewport().set_input_as_handled()
	queue_redraw()


func _vec(origin: Vector2, p: Vector2, radius: float) -> Vector2:
	var v := (p - origin) / radius
	return v.limit_length(1.0)


func release_all() -> void:
	_touch.clear()
	move = Vector2.ZERO
	aim_active = false
	aim_fire = false
	attack_held = false
	preview = {}
	queue_redraw()


var _labels := {}
var _state_key := ""
var _pulse_acc := 0.0


func _make_label(text: String, size: int, col: Color) -> Label:
	var l := UiTheme.label(text, size, col, true, 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size = Vector2(160, 24)
	add_child(l)
	return l


func _place_labels() -> void:
	if _labels.is_empty():
		_labels["aim"] = _make_label("AIM", 15, Color(1, 1, 1, 0.6))
		_labels["attack"] = _make_label("ATTACK", 15, Color.WHITE)
		_labels["ability"] = _make_label(ability_name, 13, Color(1, 1, 1, 0.9))
		_labels["super"] = _make_label(super_name, 13, Color(1, 0.92, 0.6))
	_labels["ability"].text = ability_name
	_labels["super"].text = super_name
	_labels["aim"].position = _aim_c() + Vector2(-80, AIM_R + 8)
	_labels["attack"].position = _attack_c() + Vector2(-80, 28)
	_labels["ability"].position = _ability_c() + Vector2(-80, ABILITY_R + 4)
	_labels["super"].position = _super_c() + Vector2(-80, SUPER_R + 6)
	_labels["super"].modulate.a = 1.0 if super_charge >= 1.0 else 0.6


## Redraw only when something visible changed (input, cooldown steps, super charge); pulse at ~20 Hz when ready.
func _process(delta: float) -> void:
	_t += delta
	var key := "%s|%s|%s|%s|%s|%d|%d|%s" % [move.snapped(Vector2(0.02, 0.02)), aim.snapped(Vector2(0.02, 0.02)), aim_active, attack_held,
		_touch.size(), int(ability_cd * 40.0), int(super_charge * 60.0), preview.size()]
	if super_charge >= 1.0:
		_pulse_acc += delta
		if _pulse_acc > 0.05:
			_pulse_acc = 0.0
			key += str(_t)
	if key != _state_key:
		_state_key = key
		_place_labels()
		queue_redraw()


# ---------------- drawing
func _draw() -> void:
	Prof.begin("touch")
	var dark := Color(0.04, 0.05, 0.14, 0.55)
	# MOVE stick (ghost at rest position when idle)
	var move_t := _find("move")
	var mo := _move_origin if not move_t.is_empty() else Vector2(_safe.position.x + 150, _safe.end.y - 140)
	var alpha := 1.0 if not move_t.is_empty() else 0.45
	draw_circle(mo, MOVE_R + 8, Color(0, 0, 0, 0.18 * alpha))
	draw_arc(mo, MOVE_R, 0, TAU, 48, Color(1, 1, 1, 0.35 * alpha), 4.0, true)
	var knob := mo + move * MOVE_R
	draw_circle(knob, 34, Color(1, 1, 1, 0.75 * alpha))
	draw_circle(knob, 26, Color(0.85, 0.9, 1.0, 0.9 * alpha))
	# AIM stick
	var ac := _aim_c()
	draw_circle(ac, AIM_R + 6, dark)
	draw_arc(ac, AIM_R, 0, TAU, 48, Color(1, 0.45, 0.4, 0.75 if aim_active else 0.45), 4.0, true)
	if aim_fire:
		draw_arc(ac, AIM_R + 7, 0, TAU, 48, Color(1, 0.8, 0.3, 0.9), 3.0, true)
	var aim_t := _find("aim")
	var ak := ac + (_vec(ac, aim_t.pos, AIM_R) * AIM_R if not aim_t.is_empty() else Vector2.ZERO)
	draw_circle(ak, 28, Color(1, 0.5, 0.45, 0.85))
	# ATTACK
	var atk := _attack_c()
	var held := attack_held
	_draw_button(atk, ATTACK_R * (0.94 if held else 1.0), Color("ff5a4e"), Color("b3203a"), 0.0)
	_draw_icon_burst(atk, 26)
	# ABILITY
	var ab := _ability_c()
	_draw_button(ab, ABILITY_R, Color("4cc3ff"), Color("1f5bd1"), ability_cd)
	_draw_icon_diamond(ab, 17)
	# SUPER
	var sp := _super_c()
	var ready := super_charge >= 1.0
	if ready:
		var pulse := 0.5 + 0.5 * sin(_t * 7.0)
		draw_circle(sp, SUPER_R + 10 + pulse * 6, Color(1, 0.82, 0.25, 0.25 + pulse * 0.25))
	_draw_button(sp, SUPER_R, Color("ffe066") if ready else Color("8a7a40"), Color("c98a00") if ready else Color("4a4026"), 0.0)
	draw_arc(sp, SUPER_R + 4, -PI / 2, -PI / 2 + TAU * super_charge, 48, Color("ffd23f"), 7.0, true)
	_draw_icon_star(sp, 22, ready)
	# skill drag preview line on the button
	if not preview.is_empty():
		var c := _ability_c() if preview.slot == &"ability" else _super_c()
		draw_line(c, c + preview.dir * 130.0 * preview.mag, Color(1, 1, 1, 0.6), 4.0, true)
		draw_circle(c + preview.dir * 130.0 * preview.mag, 10, Color(1, 1, 1, 0.8))
	Prof.end("touch")


func _find(kind: String) -> Dictionary:
	for t in _touch.values():
		if t.kind == kind:
			return t
	return {}


func _draw_button(c: Vector2, r: float, top: Color, bottom: Color, cooldown: float) -> void:
	draw_circle(c + Vector2(0, 5), r, Color(0, 0, 0, 0.35))
	draw_circle(c, r, bottom)
	draw_circle(c - Vector2(0, r * 0.08), r * 0.88, top)
	draw_circle(c - Vector2(r * 0.25, r * 0.35), r * 0.3, Color(1, 1, 1, 0.18))
	draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.55), 3.0, true)
	if cooldown > 0.0:
		var pts := PackedVector2Array([c])
		var steps := 32
		for i in steps + 1:
			var a := -PI / 2 + TAU * cooldown * float(i) / steps
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, Color(0.02, 0.03, 0.1, 0.7))


func _draw_label(p: Vector2, text: String, size: int, col: Color) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
	draw_string_outline(_font, p - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0.05, 0.03, 0.12, 0.9))
	draw_string(_font, p - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_icon_burst(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0 - PI / 2
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c - Vector2(0, 8) + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, Color(1, 1, 1, 0.95))


func _draw_icon_diamond(c: Vector2, r: float) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, 0), c + Vector2(0, r), c + Vector2(-r * 0.7, 0)]), Color(1, 1, 1, 0.95))


func _draw_icon_star(c: Vector2, r: float, ready: bool) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0 - PI / 2 + (_t * 1.5 if ready else 0.0)
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, Color(1, 1, 1, 0.95) if ready else Color(1, 1, 1, 0.5))
