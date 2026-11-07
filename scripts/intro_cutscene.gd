extends Node3D

const PlayerRig = preload("res://scripts/player_rig.gd")
const WakeSequence = preload("res://scripts/wake_sequence.gd")
const GAME_SCENE := "res://scenes/main.tscn"
const LANE_X := 1.2
const WALK_SPEED := 1.8
const WALK_TIME := 9.0
const STOP_Z := -WALK_SPEED * WALK_TIME
const VAN_START_Z := 40.0
const VAN_STOP_Z := STOP_Z + 8.0
const FP_WALK_TIME := 5.4
const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float radius = 1.6;
void fragment() {
	float d = length(UV - vec2(0.5)) * 1.414;
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(radius - 0.4, radius, d));
}
"""

var _done := false
var _phase := 0
var _t := 0.0
var _cam: Camera3D
var _fp_root: Node3D
var _player_root: Node3D
var _rig: Node3D
var _van: Node3D
var _kidnapper: Node3D
var _kid_arm: Node3D
var _kid_light: OmniLight3D
var _walking := false
var _walk_phase := 0.0
var _step_timer := 0.0
var _chase_volume := -80.0
var _fp_bob := true
var _van_last_z := VAN_START_Z
var _engine: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _black: ColorRect
var _flash: ColorRect
var _vignette: ShaderMaterial
var _caption: Label
var _sounds := {}


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_make_sounds()
	_build_world()
	_build_overlay()
	_run()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
		_finish()


func _process(delta: float) -> void:
	_t += delta
	if _phase == 1:
		_update_phase_one(delta)
	elif _phase == 2:
		_update_phase_two(delta)


func _wait(seconds: float) -> bool:
	await get_tree().create_timer(seconds).timeout
	return not _done


func _finish() -> void:
	if _done:
		return
	_done = true
	WakeSequence.pending = true
	get_tree().change_scene_to_file(GAME_SCENE)


func _run() -> void:
	# Scene 1: third person, a black van creeps up behind the walker.
	_phase = 1
	_walking = true
	_van.position.z = VAN_START_Z
	_fade(0.0, 1.5)
	var walk := create_tween()
	walk.tween_property(_player_root, "position:z", STOP_Z, WALK_TIME)
	var drive := create_tween()
	drive.tween_property(_van, "position:z", VAN_STOP_Z, WALK_TIME + 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not await _wait(WALK_TIME):
		return
	_walking = false
	var turn := create_tween()
	turn.tween_property(_player_root, "rotation:y", 2.5, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not await _wait(0.9):
		return
	_play("door", -4.0)
	if not await _wait(1.6):
		return
	_fade(1.0, 0.5)
	if not await _wait(0.8):
		return

	# Scene 2: first person, walking, then struck from behind.
	_phase = 2
	_rig.visible = false
	_engine.volume_db = -80.0
	_fp_root.position = Vector3(LANE_X, 1.62, STOP_Z)
	_cam.position = Vector3.ZERO
	_cam.rotation = Vector3.ZERO
	_cam.make_current()
	_fade(0.0, 0.8)
	_walking = true
	_step_timer = 0.0
	var fp_walk := create_tween()
	fp_walk.tween_property(_fp_root, "position:z", STOP_Z - FP_WALK_TIME * 1.4, FP_WALK_TIME)
	var chase := create_tween()
	chase.tween_interval(2.4)
	chase.tween_property(self, "_chase_volume", -6.0, FP_WALK_TIME - 2.4)
	if not await _wait(FP_WALK_TIME):
		return
	_walking = false
	_fp_bob = false
	_hit_from_behind()
	if not await _wait(1.4):
		return

	# Scene 3: on the ground, the world fades, and the kidnapper looms over you.
	_heart.play()
	var heart := create_tween()
	heart.tween_property(_heart, "volume_db", -2.0, 6.0)
	create_tween().tween_property(_vignette, "shader_parameter/radius", 0.75, 3.0)
	var look := create_tween().set_parallel(true)
	look.tween_property(_fp_root, "rotation:y", PI, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	look.tween_property(_cam, "rotation:x", 0.7, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var loom := create_tween().set_parallel(true)
	loom.tween_property(_kidnapper, "position:z", _kidnapper.position.z - 1.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	loom.tween_property(_kidnapper, "rotation:x", -0.32, 3.0).set_delay(1.0)
	_kid_light.visible = true
	if not await _wait(3.0):
		return
	var dim := create_tween()
	dim.tween_property(_vignette, "shader_parameter/radius", 0.3, 4.0)
	var pulse := create_tween()
	for i in 3:
		pulse.tween_property(_black, "color:a", 0.65, 0.5)
		pulse.tween_property(_black, "color:a", 0.15, 0.7)
	pulse.tween_property(_black, "color:a", 1.0, 1.4)
	_caption.text = "Who... are you...?"
	create_tween().tween_property(_caption, "modulate:a", 1.0, 0.8)
	if not await _wait(5.0):
		return
	create_tween().tween_property(_heart, "volume_db", -40.0, 1.5)
	create_tween().tween_property(_caption, "modulate:a", 0.0, 0.6)
	if not await _wait(2.0):
		return
	_finish()


func _hit_from_behind() -> void:
	_play("thud", 2.0)
	_kidnapper.position = Vector3(LANE_X, 0.0, _fp_root.position.z + 1.8)
	_kidnapper.visible = true
	var swing := create_tween()
	swing.tween_property(_kid_arm, "rotation:x", -2.4, 0.12)
	_flash.color.a = 0.9
	create_tween().tween_property(_flash, "color:a", 0.0, 0.5)
	var shake := create_tween()
	for i in 6:
		shake.tween_property(_cam, "h_offset", randf_range(-0.12, 0.12), 0.04)
		shake.tween_property(_cam, "v_offset", randf_range(-0.12, 0.12), 0.04)
	shake.tween_property(_cam, "h_offset", 0.0, 0.1)
	shake.tween_property(_cam, "v_offset", 0.0, 0.1)
	var fall := create_tween().set_parallel(true)
	fall.tween_property(_fp_root, "position:y", 0.28, 1.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fall.tween_property(_fp_root, "position:z", _fp_root.position.z - 0.7, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fall.tween_property(_cam, "rotation:x", -0.5, 0.35)
	fall.tween_property(_cam, "rotation:z", 1.2, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(0.8).timeout.connect(func(): _play("thud", -6.0))


func _update_phase_one(delta: float) -> void:
	var speed := WALK_SPEED if _walking else 0.0
	_walk_phase += delta * 5.6 * (speed / WALK_SPEED)
	_rig.animate(delta, speed, false, true, 0.0, -1.0, 0.0, _walk_phase, true, Vector3(0, 0, -speed))
	_tick_steps(delta, -12.0, 0.0)
	var focus := _player_root.position + Vector3(0, 1.1, 0)
	var back_pull := clampf(_t / 4.0, 0.0, 1.0)
	_cam.global_position = _player_root.position + Vector3(2.3 - back_pull * 0.8, 1.6 - back_pull * 0.2, 3.8 + back_pull * 0.4)
	_cam.look_at(focus - Vector3(0, 0, (1.0 - back_pull) * 2.5), Vector3.UP)
	var van_speed := absf(_van.position.z - _van_last_z) / maxf(delta, 0.0001)
	_van_last_z = _van.position.z
	_engine.volume_db = lerpf(-30.0, -8.0, clampf(1.0 - (_van.position.z - _player_root.position.z) / 60.0, 0.0, 1.0))
	_engine.pitch_scale = 0.75 + clampf(van_speed / 10.0, 0.0, 1.0) * 0.5


func _update_phase_two(delta: float) -> void:
	if _fp_bob:
		_cam.position.y = sin(_t * 9.0) * 0.045
		_cam.position.x = cos(_t * 4.5) * 0.03
	_tick_steps(delta, -10.0, 0.0)
	if _walking and _chase_volume > -60.0:
		_chase_steps(delta)


func _tick_steps(delta: float, volume: float, _unused: float) -> void:
	if not _walking:
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = 0.52
		_play("step", volume, 0.12)


var _chase_timer := 0.0


func _chase_steps(delta: float) -> void:
	_chase_timer -= delta
	if _chase_timer <= 0.0:
		_chase_timer = 0.34
		_play("step", _chase_volume, 0.15)


func _fade(to_alpha: float, seconds: float) -> void:
	create_tween().tween_property(_black, "color:a", to_alpha, seconds)


func _play(sound: String, volume := 0.0, jitter := 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _sounds[sound]
	p.volume_db = volume
	p.pitch_scale = randf_range(1.0 - jitter, 1.0 + jitter)
	p.bus = "SFX"
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _synth(seconds: float, f: Callable, loop := false) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(clampf(f.call(float(i) / rate), -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = count
	return wav


func _heart_wave(t: float) -> float:
	var beat2 := maxf(t - 0.24, 0.0)
	var second := sin(TAU * 50.0 * beat2) * exp(-18.0 * beat2) * 0.8 if t >= 0.24 else 0.0
	return (sin(TAU * 55.0 * t) * exp(-18.0 * t) + second) * 0.9


func _make_sounds() -> void:
	_sounds["step"] = _synth(0.22, func(t): return (randf_range(-1.0, 1.0) * 0.35 + sin(TAU * 70.0 * t) * 0.5) * exp(-26.0 * t))
	_sounds["thud"] = _synth(0.7, func(t): return (sin(TAU * (95.0 - 55.0 * minf(t * 3.0, 1.0)) * t) * 0.9 + randf_range(-1.0, 1.0) * 0.5 * exp(-40.0 * t)) * exp(-7.0 * t))
	_sounds["door"] = _synth(0.5, func(t): return (randf_range(-1.0, 1.0) * 0.5 * exp(-30.0 * t) + sin(TAU * 130.0 * t) * 0.5 * exp(-14.0 * t)) * minf(t / 0.002, 1.0))
	_sounds["engine"] = _synth(2.0, func(t): return sin(TAU * 48.0 * t) * 0.4 + sin(TAU * 96.0 * t) * 0.22 + sin(TAU * 144.0 * t) * 0.08 + randf_range(-1.0, 1.0) * 0.03, true)
	_sounds["heart"] = _synth(0.9, _heart_wave, true)

	_engine = AudioStreamPlayer.new()
	_engine.stream = _sounds["engine"]
	_engine.volume_db = -40.0
	_engine.bus = "SFX"
	add_child(_engine)
	_engine.play()
	_heart = AudioStreamPlayer.new()
	_heart.stream = _sounds["heart"]
	_heart.volume_db = -30.0
	_heart.bus = "SFX"
	add_child(_heart)


func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, emissive := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(color, emissive)
	parent.add_child(mi)
	return mi


func _mat(color: Color, emissive := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emissive
	return m


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.015, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.28, 0.45)
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.05, 0.1)
	env.fog_density = 0.018
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.45, 0.5, 0.8)
	moon.light_energy = 0.35
	moon.rotation_degrees = Vector3(-50, 30, 0)
	add_child(moon)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 260)
	ground.mesh = pm
	ground.position = Vector3(0, 0, -50)
	ground.material_override = _mat(Color(0.05, 0.08, 0.05))
	add_child(ground)
	_box(self, Vector3(0, 0.01, -50), Vector3(7.0, 0.02, 260), Color(0.1, 0.1, 0.12))
	for i in 40:
		_box(self, Vector3(0, 0.025, 40 - i * 4.0), Vector3(0.14, 0.01, 1.6), Color(0.7, 0.65, 0.35), 0.15)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 50:
		var side := -1.0 if i % 2 == 0 else 1.0
		var tree := Node3D.new()
		tree.position = Vector3(side * rng.randf_range(6.0, 22.0), 0.0, 45.0 - i * 3.2)
		add_child(tree)
		var h := rng.randf_range(3.0, 6.0)
		_box(tree, Vector3(0, h / 2.0, 0), Vector3(0.4, h, 0.4), Color(0.05, 0.035, 0.03))
		_box(tree, Vector3(0, h + 0.8, 0), Vector3(2.2, 2.4, 2.2), Color(0.03, 0.07, 0.04))
	for i in 8:
		var pole := Node3D.new()
		pole.position = Vector3(-3.6, 0.0, 30.0 - i * 14.0)
		add_child(pole)
		_box(pole, Vector3(0, 2.6, 0), Vector3(0.12, 5.2, 0.12), Color(0.08, 0.08, 0.09))
		_box(pole, Vector3(0.4, 5.2, 0), Vector3(0.9, 0.1, 0.2), Color(0.08, 0.08, 0.09))
		_box(pole, Vector3(0.8, 5.12, 0), Vector3(0.3, 0.08, 0.2), Color(1.0, 0.85, 0.5), 3.0)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0.8, 4.9, 0)
		lamp.light_color = Color(1.0, 0.8, 0.5)
		lamp.light_energy = 2.2
		lamp.omni_range = 12.0
		pole.add_child(lamp)
	var glow_colors := [Color(1, 0.3, 0.2), Color(1, 0.75, 0.2), Color(0.3, 0.8, 1.0), Color(0.9, 0.3, 0.8)]
	for i in 16:
		var c: Color = glow_colors[i % glow_colors.size()]
		_box(self, Vector3(-9.0 + i * 1.2, 5.0 + sin(i) * 0.6, -62.0 - (i % 3) * 2.0), Vector3(0.35, 0.35, 0.35), c, 4.0)
	var fair := OmniLight3D.new()
	fair.position = Vector3(0, 6, -60)
	fair.light_color = Color(1.0, 0.55, 0.35)
	fair.light_energy = 3.0
	fair.omni_range = 40.0
	add_child(fair)

	_player_root = Node3D.new()
	_player_root.position = Vector3(LANE_X, 0.0, 0.0)
	add_child(_player_root)
	var head := Node3D.new()
	head.position = Vector3(0, 1.62, 0)
	_player_root.add_child(head)
	_rig = PlayerRig.new()
	_player_root.add_child(_rig)
	_rig.setup(head)

	_van = _build_van()
	_van.position = Vector3(LANE_X, 0.0, VAN_START_Z)
	add_child(_van)

	_fp_root = Node3D.new()
	_fp_root.position = Vector3(LANE_X, 1.62, 0)
	add_child(_fp_root)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 250.0
	_fp_root.add_child(_cam)
	_cam.make_current()

	_kidnapper = _build_kidnapper()
	_kidnapper.visible = false
	add_child(_kidnapper)
	_kid_light = OmniLight3D.new()
	_kid_light.position = Vector3(0, 1.9, -1.0)
	_kid_light.light_color = Color(0.75, 0.8, 1.0)
	_kid_light.light_energy = 0.9
	_kid_light.omni_range = 4.0
	_kid_light.visible = false
	_kidnapper.add_child(_kid_light)


func _build_van() -> Node3D:
	var van := Node3D.new()
	var paint := Color(0.02, 0.02, 0.025)
	_box(van, Vector3(0, 1.25, 0.5), Vector3(2.0, 1.7, 3.8), paint)
	_box(van, Vector3(0, 0.95, -2.0), Vector3(2.0, 0.9, 1.3), paint)
	var screen := _box(van, Vector3(0, 1.7, -1.5), Vector3(1.8, 0.75, 0.1), Color(0.08, 0.1, 0.16))
	screen.rotation.x = -0.45
	_box(van, Vector3(0, 0.35, 0.0), Vector3(2.05, 0.3, 5.0), Color(0.05, 0.05, 0.06))
	for x in [-1.0, 1.0]:
		for z in [-1.7, 1.9]:
			var w := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.4
			cm.bottom_radius = 0.4
			cm.height = 0.26
			w.mesh = cm
			w.rotation.z = PI / 2.0
			w.position = Vector3(x * 1.0, 0.4, z)
			w.material_override = _mat(Color(0.01, 0.01, 0.01))
			van.add_child(w)
		_box(van, Vector3(x * 0.7, 0.95, -2.68), Vector3(0.35, 0.2, 0.06), Color(1.0, 0.95, 0.8), 6.0)
		_box(van, Vector3(x * 0.8, 0.9, 2.42), Vector3(0.3, 0.2, 0.06), Color(1.0, 0.1, 0.05), 2.0)
		var spot := SpotLight3D.new()
		spot.position = Vector3(x * 0.7, 0.95, -2.8)
		spot.spot_range = 45.0
		spot.spot_angle = 26.0
		spot.light_energy = 7.0
		spot.light_color = Color(1.0, 0.95, 0.8)
		van.add_child(spot)
	return van


func _build_kidnapper() -> Node3D:
	var k := Node3D.new()
	var cloth := Color(0.025, 0.025, 0.03)
	for x in [-1.0, 1.0]:
		_box(k, Vector3(x * 0.12, 0.43, 0), Vector3(0.18, 0.86, 0.2), cloth)
	_box(k, Vector3(0, 1.2, 0), Vector3(0.52, 0.68, 0.3), cloth)
	_box(k, Vector3(-0.34, 1.15, 0), Vector3(0.12, 0.62, 0.14), cloth)
	_kid_arm = Node3D.new()
	_kid_arm.position = Vector3(0.34, 1.48, 0)
	k.add_child(_kid_arm)
	_box(_kid_arm, Vector3(0, -0.3, 0), Vector3(0.12, 0.62, 0.14), cloth)
	_box(_kid_arm, Vector3(0, -0.55, -0.35), Vector3(0.07, 0.07, 0.9), Color(0.3, 0.3, 0.33))
	_box(k, Vector3(0, 1.72, 0), Vector3(0.26, 0.3, 0.28), Color(0.85, 0.83, 0.78))
	_box(k, Vector3(0, 1.9, 0.02), Vector3(0.32, 0.16, 0.34), cloth)
	_box(k, Vector3(0, 1.62, 0.03), Vector3(0.34, 0.5, 0.26), cloth)
	for x in [-1.0, 1.0]:
		_box(k, Vector3(x * 0.065, 1.76, -0.145), Vector3(0.05, 0.035, 0.01), Color(0, 0, 0))
	_box(k, Vector3(0, 1.65, -0.145), Vector3(0.1, 0.012, 0.01), Color(0.2, 0.0, 0.0))
	return k


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var vig := ColorRect.new()
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	_vignette = ShaderMaterial.new()
	_vignette.shader = shader
	vig.material = _vignette
	layer.add_child(vig)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 1)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_black)
	_caption = Label.new()
	_caption.anchor_left = 0.0
	_caption.anchor_right = 1.0
	_caption.anchor_top = 1.0
	_caption.anchor_bottom = 1.0
	_caption.offset_top = -150.0
	_caption.offset_bottom = -90.0
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 32)
	_caption.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.modulate.a = 0.0
	layer.add_child(_caption)
	var skip := Label.new()
	skip.text = "Esc / Space: skip"
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -220.0
	skip.offset_right = -16.0
	skip.offset_top = 12.0
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip.add_theme_font_size_override("font_size", 14)
	skip.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	layer.add_child(skip)
