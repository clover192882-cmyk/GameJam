extends CanvasLayer

const VIGNETTE_POINTS := 100.0
const VIGNETTE_MIN := 0.15
const VIGNETTE_MAX := 0.9
const FOV_AMPLITUDE := 5.0
const FOV_PERIOD := 4.0

const SHADER_CODE := """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.3;
uniform vec3 tint = vec3(0.0);
void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.0, 0.85));
	float v = smoothstep(0.22, 0.8, d);
	COLOR = vec4(tint, v * intensity);
}
"""

var player: Node
var _mat: ShaderMaterial
var _intensity := VIGNETTE_MIN
var _t := 0.0


func _ready() -> void:
	layer = 3
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	var rect := ColorRect.new()
	rect.material = _mat
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)


func _process(delta: float) -> void:
	_t += delta
	var low := PointManager.health <= 1
	var need := 1.0 - clampf(PointManager.points / VIGNETTE_POINTS, 0.0, 1.0)
	var target := lerpf(VIGNETTE_MIN, VIGNETTE_MAX, need)
	if low:
		target = minf(target + 0.15 + 0.05 * sin(_t * 4.0), VIGNETTE_MAX)
	_intensity = lerpf(_intensity, target, minf(delta * 2.0, 1.0))
	_mat.set_shader_parameter("intensity", _intensity)
	_mat.set_shader_parameter("tint", Vector3(0.14, 0.0, 0.0) if low else Vector3.ZERO)
	if player:
		player.fov_extra = sin(_t * TAU / FOV_PERIOD) * FOV_AMPLITUDE if low else 0.0
