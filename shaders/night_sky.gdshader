shader_type sky;

uniform vec3 moon_dir = vec3(-0.45, 0.62, 0.6);
uniform vec3 top_color : source_color = vec3(0.02, 0.05, 0.16);
uniform vec3 horizon_color : source_color = vec3(0.12, 0.2, 0.36);
uniform vec3 ground_color : source_color = vec3(0.04, 0.07, 0.11);
uniform float cloud_speed = 0.006;
uniform float cloud_cover = 0.55;

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
		p = p * 2.03 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 col = mix(horizon_color, top_color, pow(clamp(dir.y, 0.0, 1.0), 0.45));
	if (dir.y < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-dir.y * 3.0, 0.0, 1.0));
	}

	vec3 m = normalize(moon_dir);
	float d = dot(dir, m);

	float cloud = 0.0;
	if (dir.y > 0.0) {
		vec2 uv = dir.xz / (dir.y + 0.18) * 1.3 + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4);
		float c = fbm(uv);
		cloud = smoothstep(1.0 - cloud_cover - 0.12, 1.0 - cloud_cover + 0.28, c);
		cloud *= smoothstep(0.0, 0.22, dir.y);
	}

	// Stars, hidden by clouds.
	vec2 sp = dir.xz / (abs(dir.y) + 0.6) * 55.0;
	float star = step(0.9965, hash(floor(sp))) * smoothstep(0.25, 0.7, dir.y);
	col += vec3(0.9, 0.95, 1.0) * star * (1.0 - cloud) * 0.8;

	float disc = smoothstep(0.9962, 0.9972, d);
	float halo = pow(max(d, 0.0), 120.0) * 0.55 + pow(max(d, 0.0), 14.0) * 0.14;
	col += vec3(0.55, 0.65, 0.9) * halo * (1.0 - cloud * 0.5);
	col = mix(col, vec3(0.96, 0.97, 1.0) * 1.6, disc * (1.0 - cloud * 0.8));

	// Moonlit clouds: brighter and silver near the moon, dark blue elsewhere.
	float lit = pow(max(d, 0.0), 5.0);
	vec3 cloud_col = mix(vec3(0.16, 0.22, 0.36), vec3(0.66, 0.74, 0.9), clamp(lit * 0.9 + 0.1, 0.0, 1.0));
	col = mix(col, cloud_col, cloud * 0.85);

	COLOR = col;
}
