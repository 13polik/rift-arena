// Overhead HP bar: camera-facing quad drawn on top of the world. hp = current, lag = recently lost (white chunk).
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled, depth_draw_never;

instance uniform float hp = 1.0;
instance uniform float lag = 1.0;
instance uniform vec4 fill_color : source_color = vec4(0.35, 1.0, 0.45, 1.0);
instance uniform float segments = 8.0;
instance uniform float shield = 0.0;  // spawn protection shimmer

void vertex() {
	// billboard that keeps the node's world position
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = vec3(0.06, 0.06, 0.14);
	if (uv.x < lag) col = vec3(1.0, 0.92, 0.75);
	if (uv.x < hp) {
		col = fill_color.rgb * (uv.y < 0.45 ? 1.15 : 0.82);
		float seg = step(0.9, fract(uv.x * segments));
		col *= 1.0 - seg * 0.45;
	}
	col += vec3(0.5, 0.8, 1.0) * shield * (0.5 + 0.5 * sin(TIME * 12.0 + uv.x * 10.0));
	float bx = min(uv.x, 1.0 - uv.x) * 9.0;
	float by = min(uv.y, 1.0 - uv.y);
	if (bx < 0.05 || by < 0.16) col = vec3(0.02, 0.02, 0.06);
	ALBEDO = col;
	ALPHA = 1.0;
}
