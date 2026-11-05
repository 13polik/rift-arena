// Procedural arena floor: stylized tiles, team-tinted halves, lane paint, glowing core ring and base pads.
// No textures -> tiny memory footprint, crisp at any resolution.
shader_type spatial;

uniform vec3 tile_a : source_color = vec3(0.23, 0.27, 0.42);
uniform vec3 tile_b : source_color = vec3(0.26, 0.31, 0.48);
uniform vec3 grout : source_color = vec3(0.13, 0.15, 0.27);
uniform vec3 blue_tint : source_color = vec3(0.18, 0.45, 1.0);
uniform vec3 red_tint : source_color = vec3(1.0, 0.25, 0.32);
uniform vec3 energy : source_color = vec3(0.35, 0.95, 1.0);
uniform float half_width = 19.0;
uniform float base_x = 15.6;
uniform float time_scale = 1.0;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = wpos.xz;
	vec2 cell = floor(p / 1.6);
	vec2 f = fract(p / 1.6);
	float n = hash(cell);
	vec3 col = mix(tile_a, tile_b, step(0.5, mod(cell.x + cell.y, 2.0)));
	col *= 0.92 + n * 0.12;
	// bevel / grout lines
	float e = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	col = mix(grout, col, smoothstep(0.02, 0.06, e));
	col += smoothstep(0.1, 0.0, abs(f.y - 0.92)) * 0.03;
	// team halves
	float side = clamp(p.x / half_width, -1.0, 1.0);
	col = mix(col, col * 0.6 + blue_tint * 0.4, smoothstep(0.0, -1.0, side) * 0.55);
	col = mix(col, col * 0.6 + red_tint * 0.4, smoothstep(0.0, 1.0, side) * 0.55);
	vec3 emit = vec3(0.0);
	// lane paint (dashed side lane guides)
	float lane = (1.0 - smoothstep(0.05, 0.12, abs(abs(p.y) - 8.6))) * step(0.5, fract(p.x * 0.25));
	col = mix(col, vec3(0.95, 0.85, 0.45), lane * 0.55 * step(abs(p.x), 13.0));
	// center ring + rotating energy dashes
	float d = length(p);
	float ring = 1.0 - smoothstep(0.04, 0.12, abs(d - 4.6));
	float ang = atan(p.y, p.x);
	float dash = step(0.5, fract(ang * 3.8197 + TIME * 0.15 * time_scale));
	emit += energy * ring * (0.6 + dash * 0.9);
	col = mix(col, vec3(0.12, 0.2, 0.35), (1.0 - smoothstep(4.4, 4.6, d)) * 0.5);
	float inner = 1.0 - smoothstep(0.03, 0.08, abs(d - 2.4));
	emit += energy * inner * 0.5;
	// base pads
	for (int i = 0; i < 2; i++) {
		float sx = i == 0 ? -base_x : base_x;
		vec3 tc = i == 0 ? blue_tint : red_tint;
		float bd = length(p - vec2(sx, 0.0));
		float pad = 1.0 - smoothstep(0.05, 0.13, abs(bd - 2.6));
		float pulse = 0.6 + 0.4 * sin(TIME * 3.0 * time_scale - bd * 2.0);
		emit += tc * pad * 1.4 * pulse;
		col = mix(col, tc * 0.45, (1.0 - smoothstep(2.4, 2.6, bd)) * 0.45);
	}
	// edge vignette
	float edge = smoothstep(half_width - 1.0, half_width + 0.3, abs(p.x)) + smoothstep(11.0, 12.3, abs(p.y));
	col *= 1.0 - clamp(edge, 0.0, 1.0) * 0.35;
	ALBEDO = col;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	EMISSION = emit;
}
