// Walls, crates and buildings: one shader, style chosen by uniforms.
// Draws beveled panel edges, hazard stripes, glowing trims and lit windows procedurally from object-space position.
shader_type spatial;
render_mode diffuse_toon;

uniform vec3 base_color : source_color = vec3(0.4, 0.35, 0.7);
uniform vec3 edge_color : source_color = vec3(0.65, 0.58, 0.95);
uniform vec3 trim_color : source_color = vec3(0.3, 0.95, 1.0);
uniform float trim_strength = 1.4;
uniform float panel_size = 1.0;
uniform float edge_width = 0.06;
uniform float stripes = 0.0;   // hazard stripes on the lower band
uniform float windows = 0.0;   // building windows
uniform vec3 window_color : source_color = vec3(1.0, 0.8, 0.45);

varying vec3 lp;   // local position (scaled to world size)
varying vec3 ln;
varying vec3 half_ext;

float hash(vec3 p) { return fract(sin(dot(p, vec3(17.1, 113.7, 59.3))) * 43758.5453); }

void vertex() {
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	lp = VERTEX * sc;
	ln = NORMAL;
	half_ext = sc * 0.5;
}

void fragment() {
	vec3 a = abs(lp);
	vec3 col = base_color;
	vec3 emit = vec3(0.0);
	// distance to the box edges on the face we are drawing
	vec3 dist = half_ext - a;
	float e;
	if (abs(ln.y) > 0.5) e = min(dist.x, dist.z);
	else if (abs(ln.x) > 0.5) e = min(dist.y, dist.z);
	else e = min(dist.x, dist.y);
	// panel grid on side faces
	vec2 uv = abs(ln.x) > 0.5 ? lp.zy : (abs(ln.z) > 0.5 ? lp.xy : lp.xz);
	vec2 g = fract(uv / panel_size);
	float seam = min(min(g.x, 1.0 - g.x), min(g.y, 1.0 - g.y));
	col *= mix(0.82, 1.0, smoothstep(0.0, 0.04, seam));
	col *= 0.94 + hash(floor(vec3(uv / panel_size, 0.0))) * 0.1;
	// bevel highlight on edges
	col = mix(edge_color, col, smoothstep(edge_width * 0.5, edge_width, e));
	// glowing trim line near the top of side faces
	if (abs(ln.y) < 0.5) {
		float top = half_ext.y - lp.y;
		float trim = 1.0 - smoothstep(0.03, 0.07, abs(top - 0.18));
		emit += trim_color * trim * trim_strength;
		if (stripes > 0.5 && lp.y < -half_ext.y + 0.35) {
			float s = step(0.5, fract((uv.x + uv.y) * 1.5));
			col = mix(col, mix(vec3(0.12), vec3(1.0, 0.78, 0.15), s), 0.85);
		}
		if (windows > 0.5) {
			vec2 wg = fract(uv / vec2(1.2, 1.4));
			vec2 wi = floor(uv / vec2(1.2, 1.4));
			float win = step(0.2, wg.x) * step(wg.x, 0.8) * step(0.25, wg.y) * step(wg.y, 0.75);
			float lit = step(0.45, hash(vec3(wi, 3.0)));
			float flick = 0.85 + 0.15 * sin(TIME * (2.0 + hash(vec3(wi, 7.0)) * 4.0));
			col = mix(col, vec3(0.08, 0.1, 0.2), win);
			emit += window_color * win * lit * 1.6 * flick * step(lp.y, half_ext.y - 0.6);
		}
	} else {
		col *= 1.12; // tops read lighter from the top-down camera
	}
	ALBEDO = col;
	ROUGHNESS = 0.75;
	EMISSION = emit;
}
