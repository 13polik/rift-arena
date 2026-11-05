// Bushes: wind sway, per-instance color variation, and a dithered "see-through" hole around the local hero
// (no alpha blending -> no sorting cost on mobile).
shader_type spatial;
render_mode cull_back, diffuse_toon;

uniform vec3 color_a : source_color = vec3(0.05, 0.42, 0.36);
uniform vec3 color_b : source_color = vec3(0.1, 0.62, 0.38);
uniform vec3 tip : source_color = vec3(0.72, 1.0, 0.48);
uniform vec3 reveal_pos = vec3(1000.0);
uniform float reveal_radius = 1.9;
uniform float rustle = 0.0;

varying float vh;
varying vec3 wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = clamp(VERTEX.y / 1.45 + 0.5, 0.0, 1.0);
	float sway = sin(TIME * 1.8 + w.x * 0.7 + w.z * 0.5) * 0.07 + sin(TIME * 7.0 + w.x * 3.0) * rustle * 0.06;
	VERTEX.x += sway * h;
	VERTEX.z += sway * 0.6 * h;
	vh = h;
	wp = w;
}

void fragment() {
	float n = hash(floor(wp.xz * 1.3));
	vec3 c = mix(color_a, color_b, n);
	c = mix(c, tip, smoothstep(0.55, 1.0, vh) * 0.6);
	ALBEDO = c;
	ROUGHNESS = 0.9;
	EMISSION = c * 0.08;
	// dithered reveal around the local hero
	float d = length(wp.xz - reveal_pos.xz);
	if (d < reveal_radius) {
		vec2 sp = floor(FRAGCOORD.xy * 0.5);
		float dither = mod(sp.x + sp.y, 2.0);
		if (dither < 0.5 || d < reveal_radius * 0.55) discard;
	}
}
