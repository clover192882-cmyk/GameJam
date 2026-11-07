extends Node3D

const COUNT := 150
const LIT_COUNT := 6
const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec3 glow_color : source_color = vec3(0.75, 1.0, 0.25);
uniform float energy = 6.0;
uniform float time_scale = 1.0;

varying float phase;
varying float size_mul;

void vertex() {
	phase = INSTANCE_CUSTOM.x;
	size_mul = INSTANCE_CUSTOM.y;
	float t = TIME * time_scale;
	vec3 drift = vec3(sin(t * 0.6 + phase * 6.2), sin(t * 0.9 + phase * 11.0) * 0.5, cos(t * 0.5 + phase * 9.0)) * 0.9;
	vec3 center = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz + drift;
	vec3 right = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 up = normalize(INV_VIEW_MATRIX[1].xyz);
	vec3 world = center + (right * VERTEX.x + up * VERTEX.y) * size_mul;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float soft = pow(clamp(1.0 - d, 0.0, 1.0), 2.2);
	float blink = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(TIME * (1.4 + phase * 1.6) + phase * 40.0), 2.0);
	ALBEDO = glow_color * energy * soft * blink;
}
"""

var area_min := Vector3(-11.0, 0.4, -40.0)
var area_max := Vector3(120.0, 3.6, 40.0)
var keep_out_road := Vector2(24.0, 32.0)


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var shader := Shader.new()
	shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.28)
	quad.material = mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = COUNT
	var lit_positions: Array[Vector3] = []
	for i in COUNT:
		var p := Vector3(rng.randf_range(area_min.x, area_max.x), rng.randf_range(area_min.y, area_max.y), rng.randf_range(area_min.z, area_max.z))
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf_range(0.7, 1.5), 0.0, 0.0))
		if lit_positions.size() < LIT_COUNT and i % (COUNT / LIT_COUNT) == 0:
			lit_positions.append(p)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.extra_cull_margin = 4.0
	add_child(inst)

	for p in lit_positions:
		var light := OmniLight3D.new()
		light.position = p
		light.light_color = Color(0.75, 1.0, 0.3)
		light.light_energy = 0.7
		light.omni_range = 4.5
		light.shadow_enabled = false
		add_child(light)
		var tw := create_tween().set_loops()
		var base := rng.randf_range(0.4, 0.9)
		tw.tween_property(light, "light_energy", base, rng.randf_range(0.8, 1.6)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(light, "light_energy", base * 0.2, rng.randf_range(0.8, 1.6)).set_trans(Tween.TRANS_SINE)
