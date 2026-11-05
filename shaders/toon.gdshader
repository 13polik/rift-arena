// Shared cel-shaded material for characters and props.
// Colors are INSTANCE uniforms, so every part of every hero can share ONE material (fewer state changes on mobile).
shader_type spatial;
render_mode cull_back;

instance uniform vec4 albedo : source_color = vec4(1.0);
instance uniform vec4 glow : source_color = vec4(0.0, 0.0, 0.0, 0.0); // rgb = emission color, a = strength
instance uniform float flash = 0.0;      // hit flash 0..1 (white)
instance uniform float tint_amount = 0.0; // team tint overlay
instance uniform vec4 tint : source_color = vec4(1.0);
uniform float rim_strength = 0.45;
uniform float rim_power = 3.0;
uniform vec3 shadow_color : source_color = vec3(0.32, 0.27, 0.55);

void fragment() {
	// vertex COLOR carries baked part colors (white when unused); COLOR.a < 1 marks self-lit parts
	vec3 base = mix(albedo.rgb * COLOR.rgb, tint.rgb, tint_amount);
	ALBEDO = base;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = glow.rgb * glow.a + COLOR.rgb * (1.0 - COLOR.a) * 2.6 + vec3(1.0, 0.95, 0.9) * flash * 1.6 + base * rim * rim_strength;
}

// Two-band toon lighting with a colored (not black) shadow tone for a cartoon look.
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(-0.02, 0.06, ndl) * ATTENUATION;
	float soft = smoothstep(0.45, 0.6, ndl) * 0.25;
	vec3 shade = mix(shadow_color * 0.6, vec3(1.0), lit) + soft * lit;
	DIFFUSE_LIGHT += ALBEDO * shade * LIGHT_COLOR / PI * 0.9;
	// small toon highlight
	vec3 h = normalize(VIEW + LIGHT);
	float spec = smoothstep(0.92, 0.95, dot(NORMAL, h)) * lit;
	SPECULAR_LIGHT += spec * LIGHT_COLOR * 0.15;
}
