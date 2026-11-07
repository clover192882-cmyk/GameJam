extends Node

const PlayerRig = preload("res://scripts/player_rig.gd")

signal finished

var player: CharacterBody3D
var car: Node3D

var _cam: Camera3D
var _walker: Node3D
var _rig: Node3D
var _black: ColorRect
var _caption: Label
var _engine: AudioStreamPlayer
var _sounds := {}
var _done := false
var _walking := false
var _driving := false
var _phase := 0.0
var _step := 0.0
var _t := 0.0


func begin() -> void:
	_build_overlay()
	_make_sounds()
	var start := player.global_position
	player.visible = false
	_walker = Node3D.new()
	get_tree().current_scene.add_child(_walker)
	var head := Node3D.new()
	head.position = Vector3(0, 1.62, 0)
	_walker.add_child(head)
	_rig = PlayerRig.new()
	_walker.add_child(_rig)
	_rig.setup(head)
	_walker.rotation.y = -PI / 2.0
	_walker.position = Vector3(start.x, 0.0, start.z)

	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.far = 300.0
	get_tree().current_scene.add_child(_cam)
	_cam.make_current()
	_update_follow_cam()

	await _fade(1.0, 0.6)
	await _fade(0.0, 0.8)
	_walking = true
	var walk := create_tween()
	walk.tween_property(_walker, "position:x", car.position.x - 1.5, 4.2)
	await walk.finished
	_walking = false
	await _wait(0.5)
	_play("door", -2.0)
	await _wait(0.35)
	_rig.visible = false
	_walker.visible = false
	_play("door", -5.0)
	await _wait(0.8)
	_play("start", -2.0)
	_engine.volume_db = -12.0
	for l in car.get_children():
		if l is SpotLight3D:
			l.visible = true
	await _wait(1.6)

	_driving = true
	var go := create_tween().set_parallel(true)
	go.tween_property(car, "position:z", 110.0, 11.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	go.tween_property(car, "position:x", 26.2, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var steer := create_tween()
	steer.tween_property(car, "rotation:y", PI + 0.3, 1.0)
	steer.tween_property(car, "rotation:y", PI, 1.2)
	var fade_engine := create_tween()
	fade_engine.tween_interval(5.0)
	fade_engine.tween_property(_engine, "volume_db", -60.0, 6.0)
	_caption.text = "You made it out."
	create_tween().tween_property(_caption, "modulate:a", 1.0, 1.5)
	await get_tree().create_timer(7.0).timeout
	create_tween().tween_property(_caption, "modulate:a", 0.0, 1.0)
	await _fade(1.0, 2.5)
	_end()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE):
		_end()


func _end() -> void:
	if _done:
		return
	_done = true
	if _engine:
		_engine.stop()
	finished.emit()
	if _cam:
		_cam.queue_free()
	if _walker:
		_walker.queue_free()
	queue_free()


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _walker and _walker.visible:
		var speed := 1.7 if _walking else 0.0
		_phase += delta * 5.4 * (speed / 1.7)
		_rig.animate(delta, speed, false, true, 0.0, -1.0, 0.0, _phase, true, Vector3(0, 0, -speed))
		if _walking:
			_step -= delta
			if _step <= 0.0:
				_step = 0.5
				_play("step", -10.0, 0.12)
	if _driving:
		_cam.global_position = Vector3(18.0, 1.7, 5.0)
		_cam.look_at(car.global_position + Vector3(0, 0.8, 0), Vector3.UP)
		_engine.pitch_scale = 0.8 + clampf((car.position.z) / 60.0, 0.0, 1.0) * 0.9
	elif _walker and _walker.visible:
		_update_follow_cam()
	else:
		_cam.global_position = Vector3(17.5, 1.9, -4.5)
		_cam.look_at(car.global_position + Vector3(0, 0.9, 0), Vector3.UP)


func _update_follow_cam() -> void:
	_cam.global_position = _walker.position + Vector3(-3.4, 1.7, -2.6)
	_cam.look_at(_walker.position + Vector3(1.2, 1.1, 0), Vector3.UP)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _fade(to_alpha: float, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(_black, "color:a", to_alpha, seconds)
	await tw.finished


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 25
	add_child(layer)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
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
	_caption.add_theme_font_size_override("font_size", 34)
	_caption.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.modulate.a = 0.0
	layer.add_child(_caption)


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


func _make_sounds() -> void:
	_sounds["step"] = _synth(0.22, func(t): return (randf_range(-1.0, 1.0) * 0.35 + sin(TAU * 70.0 * t) * 0.5) * exp(-26.0 * t))
	_sounds["door"] = _synth(0.5, func(t): return (randf_range(-1.0, 1.0) * 0.5 * exp(-30.0 * t) + sin(TAU * 130.0 * t) * 0.5 * exp(-14.0 * t)) * minf(t / 0.002, 1.0))
	_sounds["start"] = _synth(1.4, func(t): return (sin(TAU * (30.0 + 40.0 * minf(t / 1.2, 1.0)) * t) * 0.5 + randf_range(-1.0, 1.0) * 0.12) * minf(t / 0.1, 1.0) * (1.0 - clampf((t - 1.1) / 0.3, 0.0, 1.0)))
	_sounds["engine"] = _synth(2.0, func(t): return sin(TAU * 48.0 * t) * 0.4 + sin(TAU * 96.0 * t) * 0.22 + sin(TAU * 144.0 * t) * 0.08 + randf_range(-1.0, 1.0) * 0.03, true)
	_engine = AudioStreamPlayer.new()
	_engine.stream = _sounds["engine"]
	_engine.volume_db = -80.0
	_engine.bus = "SFX"
	add_child(_engine)
	_engine.play()


func _play(sound: String, volume := 0.0, jitter := 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _sounds[sound]
	p.volume_db = volume
	p.pitch_scale = randf_range(1.0 - jitter, 1.0 + jitter)
	p.bus = "SFX"
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
