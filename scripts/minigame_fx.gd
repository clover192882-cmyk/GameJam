extends RefCounted

static func _layer(host: Node) -> CanvasLayer:
	if host.has_meta("fx_layer"):
		var existing = host.get_meta("fx_layer")
		if is_instance_valid(existing):
			return existing
	var layer := CanvasLayer.new()
	layer.layer = 9
	host.add_child(layer)
	host.set_meta("fx_layer", layer)
	return layer


# Hand sway at one heart, in roughly [-1, 1] per axis; zero otherwise.
static func shake_unit() -> Vector2:
	if PointManager.health > 1:
		return Vector2.ZERO
	var t := Time.get_ticks_msec() / 1000.0
	return Vector2((sin(t * 13.1) + 0.6 * sin(t * 7.3 + 1.0)) / 1.6, (cos(t * 11.7) + 0.6 * sin(t * 5.9 + 2.0)) / 1.6)


static func burst(host: Node, pos: Vector3, color: Color, amount := 24, speed := 4.0, size := 0.05,
		gravity := -6.0, life := 0.6, direction := Vector3.UP, spread := 180.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = direction
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	sm.material = mat
	p.mesh = sm
	host.add_child(p)
	p.global_position = pos
	p.emitting = true
	host.get_tree().create_timer(life + 0.4).timeout.connect(p.queue_free)


static func ring(host: Node, pos: Vector3, color: Color, max_radius := 1.2, dur := 0.35) -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.72, 0.86, 1.0])
	grad.colors = PackedColorArray([Color(color, 0.0), Color(color, 0.0), Color(color, 1.0), Color(color, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 2.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = tex
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.scale = Vector3.ONE * 0.1 * max_radius
	host.add_child(mi)
	mi.global_position = pos
	var tw := host.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * max_radius, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(mi.queue_free)


static func shake(host: Node, cam: Camera3D, strength := 0.02, dur := 0.25) -> void:
	if cam == null:
		return
	var tw := host.create_tween()
	tw.tween_method(func(t: float):
		if is_instance_valid(cam):
			var k := (1.0 - t) * strength
			cam.h_offset = randf_range(-k, k)
			cam.v_offset = randf_range(-k, k), 0.0, 1.0, dur)
	tw.tween_callback(func():
		if is_instance_valid(cam):
			cam.h_offset = 0.0
			cam.v_offset = 0.0)


static func flash(host: Node, color: Color, alpha := 0.25, dur := 0.25) -> void:
	var r := ColorRect.new()
	r.color = Color(color, alpha)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer(host).add_child(r)
	var tw := host.create_tween()
	tw.tween_property(r, "color:a", 0.0, dur)
	tw.tween_callback(r.queue_free)


static func popup_3d(host: Node, pos: Vector3, text: String, color: Color, pixel := 0.004) -> void:
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.pixel_size = pixel
	l.font_size = 64
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	host.add_child(l)
	l.global_position = pos
	var tw := host.create_tween()
	tw.tween_property(l, "global_position:y", pos.y + 0.3, 0.8)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


static func popup_2d(host: Node, pos: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	_layer(host).add_child(l)
	l.pivot_offset = Vector2(40, 16)
	l.scale = Vector2.ONE * 0.4
	var tw := host.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE * 1.35, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.1)
	tw.parallel().tween_property(l, "position:y", pos.y - 50.0, 0.8)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.2)
	tw.tween_callback(l.queue_free)
