// Ground decals for shockwaves, zones, aim indicators and spawn pads. Drawn on a flat quad (UV 0..1).
// progress drives the expanding ring; fill draws a soft disc; arc limits to a cone (for melee swings / aim cones).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

instance uniform vec4 color : source_color = vec4(1.0);
instance uniform float progress = 1.0;   // ring radius (0..1 of quad)
instance uniform float thickness = 0.08;
instance uniform float fill = 0.0;       // inner disc opacity
instance uniform float alpha = 1.0;
instance uniform float arc = 6.3;        // full circle by default (radians)
instance uniform float dashes = 0.0;     // >0: rotating dashed outline
instance uniform float cracks = 0.0;     // >0: ground-crack pattern (Brute slam)

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float ang = atan(p.y, p.x);
	if (abs(ang) > arc * 0.5) discard;
	float r = progress;
	float ring = 1.0 - smoothstep(0.0, thickness, abs(d - r));
	if (dashes > 0.0) ring *= step(0.45, fract(ang / 6.2832 * dashes + TIME * 0.25));
	float disc = fill * (1.0 - smoothstep(r - 0.02, r, d)) * (0.55 + 0.45 * d / max(r, 0.001));
	float crk = 0.0;
	if (cracks > 0.0) {
		float seg = floor((ang + 3.1416) / 6.2832 * 9.0);
		float jitter = (hash(seg) - 0.5) * 0.25 + sin(d * 18.0 + seg) * 0.05;
		float sa = (seg + 0.5) / 9.0 * 6.2832 - 3.1416 + jitter;
		crk = (1.0 - smoothstep(0.0, 0.035 * (1.2 - d), abs(sin(ang - sa)) * d)) * step(d, r) * cracks;
	}
	float a = clamp(ring + disc + crk, 0.0, 1.0) * alpha * color.a;
	if (a < 0.003) discard;
	ALBEDO = color.rgb * a * 1.4;
	ALPHA = a;
}
