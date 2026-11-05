class_name MenuBackground
extends ColorRect
## Animated menu backdrop (one full-screen shader: gradient, drifting hex grid, rift glow, sparkles).

var tint := Color("2a1f6b")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec4 tint : source_color;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment(){
	vec2 uv = UV;
	vec3 base = mix(vec3(0.05, 0.06, 0.15), tint.rgb, smoothstep(1.1, 0.0, length(uv - vec2(0.3, 0.2))));
	base = mix(base, vec3(0.04, 0.3, 0.38), smoothstep(0.9, 0.0, length(uv - vec2(0.85, 0.95))) * 0.6);
	vec2 g = uv * vec2(16.0, 9.0) + vec2(TIME * 0.15, TIME * 0.05);
	vec2 f = fract(g) - 0.5;
	float grid = smoothstep(0.47, 0.5, max(abs(f.x), abs(f.y)));
	base += grid * 0.035;
	float rift = smoothstep(0.03, 0.0, abs(uv.y - 0.62 - sin(uv.x * 7.0 + TIME * 0.6) * 0.04)) * (0.5 + 0.5 * sin(TIME * 2.0 + uv.x * 10.0));
	base += vec3(0.25, 0.85, 1.0) * rift * 0.35;
	vec2 cell = floor(uv * vec2(60.0, 34.0));
	vec2 sf = fract(uv * vec2(60.0, 34.0)) - 0.5;
	float star = step(0.985, hash(cell)) * (0.5 + 0.5 * sin(TIME * 3.0 + hash(cell + 3.0) * 20.0)) * smoothstep(0.18, 0.0, length(sf));
	base += star * 0.5;
	COLOR = vec4(base, 1.0);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tint", tint)
	material = m
