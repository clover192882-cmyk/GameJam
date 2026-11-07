shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 base_color : source_color = vec3(0.05, 0.16, 0.07);
uniform vec3 tip_color : source_color = vec3(0.26, 0.5, 0.2);
uniform float sway = 0.1;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = clamp(UV.y, 0.0, 1.0);
	float w = sin(TIME * 1.6 + wp.x * 0.7 + wp.z * 0.5) + 0.5 * sin(TIME * 2.9 + wp.x * 1.9);
	VERTEX.x += w * sway * h * h;
	VERTEX.z += cos(TIME * 1.3 + wp.z * 0.8) * sway * 0.5 * h * h;
}

void fragment() {
	float h = clamp(UV.y, 0.0, 1.0);
	vec3 tint = COLOR.rgb;
	ALBEDO = mix(base_color, tip_color, h) * tint;
	ROUGHNESS = 0.9;
}
