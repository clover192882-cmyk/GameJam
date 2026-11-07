shader_type spatial;

uniform vec3 grass_a : source_color = vec3(0.07, 0.2, 0.08);
uniform vec3 grass_b : source_color = vec3(0.16, 0.3, 0.1);
uniform vec3 dirt : source_color = vec3(0.22, 0.17, 0.1);
uniform vec3 fresnel_color : source_color = vec3(0.35, 0.5, 0.9);
uniform float fresnel_power = 3.0;
uniform float fresnel_strength = 0.55;

varying vec3 world_pos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.1 + 7.7;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float patches = fbm(p * 0.35);
	float fine = noise(p * 6.0) * 0.5 + noise(p * 17.0) * 0.5;
	vec3 col = mix(grass_a, grass_b, smoothstep(0.3, 0.7, patches));
	col *= 0.8 + fine * 0.4;
	float bare = smoothstep(0.62, 0.8, fbm(p * 0.6 + 31.0));
	col = mix(col, dirt * (0.8 + fine * 0.4), bare * 0.7);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), fresnel_power);
	float shimmer = 0.75 + 0.25 * noise(p * 1.5 + TIME * 0.15);
	EMISSION = fresnel_color * fresnel * fresnel_strength * shimmer;
}
