// Unshaded additive energy: Rift Core crystal, projectiles, holograms, zones. Fresnel + scrolling bands.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 color : source_color = vec4(0.4, 0.95, 1.0, 1.0);
uniform float intensity = 1.6;
uniform float fresnel_power = 1.6;
uniform float band_speed = 1.5;
uniform float band_scale = 6.0;
uniform float band_amount = 0.35;
instance uniform float fade = 1.0;

varying vec3 lp;
void vertex() { lp = VERTEX; }

void fragment() {
	float fr = pow(1.0 - abs(dot(NORMAL, VIEW)), fresnel_power);
	float bands = 0.5 + 0.5 * sin(lp.y * band_scale - TIME * band_speed);
	float a = clamp(0.25 + fr * 0.9 + bands * band_amount, 0.0, 1.0) * fade;
	ALBEDO = color.rgb * intensity * a;
	ALPHA = a * color.a;
}
