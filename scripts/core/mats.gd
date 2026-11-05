class_name Mats
extends RefCounted
## Material + mesh cache. Everything visual shares a handful of materials so the GPU does few state changes.

const TOON := preload("res://shaders/toon.gdshader")
const PANEL := preload("res://shaders/panel.gdshader")
const ENERGY := preload("res://shaders/energy.gdshader")
const RING := preload("res://shaders/ring.gdshader")
const FOLIAGE := preload("res://shaders/foliage.gdshader")
const GROUND := preload("res://shaders/ground.gdshader")

static var _cache := {}


static func toon() -> ShaderMaterial:
	if not _cache.has("toon"):
		var m := ShaderMaterial.new()
		m.shader = TOON
		_cache["toon"] = m
	return _cache["toon"]


static func ring() -> ShaderMaterial:
	if not _cache.has("ring"):
		var m := ShaderMaterial.new()
		m.shader = RING
		_cache["ring"] = m
	return _cache["ring"]


## Energy material per color (cached by color key).
static func energy(c: Color, intensity := 1.6, band := 0.35) -> ShaderMaterial:
	var key := "en_%s_%s_%s" % [c.to_html(), intensity, band]
	if not _cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = ENERGY
		m.set_shader_parameter("color", c)
		m.set_shader_parameter("intensity", intensity)
		m.set_shader_parameter("band_amount", band)
		_cache[key] = m
	return _cache[key]


static func panel(key: String, params: Dictionary) -> ShaderMaterial:
	if not _cache.has("pn_" + key):
		var m := ShaderMaterial.new()
		m.shader = PANEL
		for k in params:
			m.set_shader_parameter(k, params[k])
		_cache["pn_" + key] = m
	return _cache["pn_" + key]


## Simple unshaded emissive color (bulbs, visors, glowing trims).
static func glow(c: Color, energy := 2.0) -> StandardMaterial3D:
	var key := "gl_%s_%s" % [c.to_html(), energy]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c * energy
		_cache[key] = m
	return _cache[key]


## A MeshInstance3D using the shared toon material with per-instance colors.
static func part(mesh: Mesh, albedo: Color, glow_col := Color(0, 0, 0, 0)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = toon()
	mi.set_instance_shader_parameter(&"albedo", albedo)
	if glow_col.a > 0.0:
		mi.set_instance_shader_parameter(&"glow", glow_col)
	return mi


# ---------- cached primitive meshes (shared between all instances) ----------
static func box(size: Vector3) -> BoxMesh:
	var key := "box%s" % size
	if not _cache.has(key):
		var m := BoxMesh.new()
		m.size = size
		_cache[key] = m
	return _cache[key]


static func sphere(r: float, h := -1.0, segs := 12, rings := 8) -> SphereMesh:
	var key := "sph%s_%s_%s" % [r, h, segs]
	if not _cache.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0 if h < 0.0 else h
		m.radial_segments = segs
		m.rings = rings
		_cache[key] = m
	return _cache[key]


static func capsule(r: float, h: float) -> CapsuleMesh:
	var key := "cap%s_%s" % [r, h]
	if not _cache.has(key):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = h
		m.radial_segments = 12
		m.rings = 4
		_cache[key] = m
	return _cache[key]


static func cyl(top: float, bottom: float, h: float, segs := 12) -> CylinderMesh:
	var key := "cyl%s_%s_%s_%s" % [top, bottom, h, segs]
	if not _cache.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = h
		m.radial_segments = segs
		m.rings = 1
		_cache[key] = m
	return _cache[key]


static func prism(size: Vector3, left := 0.5) -> PrismMesh:
	var key := "pr%s_%s" % [size, left]
	if not _cache.has(key):
		var m := PrismMesh.new()
		m.size = size
		m.left_to_right = left
		_cache[key] = m
	return _cache[key]


static func torus(inner: float, outer: float) -> TorusMesh:
	var key := "tor%s_%s" % [inner, outer]
	if not _cache.has(key):
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = 24
		m.ring_segments = 8
		_cache[key] = m
	return _cache[key]


static func quad(size: Vector2) -> QuadMesh:
	var key := "quad%s" % size
	if not _cache.has(key):
		var m := QuadMesh.new()
		m.size = size
		m.orientation = PlaneMesh.FACE_Y
		_cache[key] = m
	return _cache[key]
