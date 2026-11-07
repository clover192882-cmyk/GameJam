extends Node

signal power_changed(power: float)
signal stats_changed(darts_left: int, pops: int, net: int)
signal dart_thrown
signal dart_resolved(hit: bool)
signal round_finished(net: int, pops: int, misses: int)
signal closed

# Higher difficulties pay more per pop but also cost more per miss, and use smaller balloons.
const DIFFICULTIES := [
	{"name": "Easy", "darts": ROUNDS_PER_SESSION, "balloon_scale": 1.4, "bar_speed": 0.7, "reward_per_pop": 3, "penalty_per_miss": 2},
	{"name": "Medium", "darts": ROUNDS_PER_SESSION, "balloon_scale": 1.0, "bar_speed": 1.1, "reward_per_pop": 6, "penalty_per_miss": 4},
	{"name": "Hard", "darts": ROUNDS_PER_SESSION, "balloon_scale": 0.7, "bar_speed": 1.5, "reward_per_pop": 12, "penalty_per_miss": 8},
]
const DART_MESH := preload("res://assets/models/dart_single.res")
const ROUNDS_PER_SESSION := 5
const BALLOON_RADIUS := 0.16
const DART_TIP_RADIUS := 0.04
const CHARGE_RATE := 0.6
const DART_SPEED := 14.0
const MIN_RANGE := 0.9
const MAX_RANGE := 3.7
const SPAWN_X := Vector2(-1.3, 1.3)
const SPAWN_Y := Vector2(1.4, 2.1)
const SPAWN_Z := Vector2(-0.95, 0.35)
const MIN_BALLOON_GAP := 0.55
const GRAVITY := 4.0
const WALL_Z := -1.1
const COUNTER_TOP := 1.0
const MAX_FLIGHT := 3.0
const PREVIEW_DOTS := 28
const PREVIEW_STEP := 1.0 / 60.0
const PREVIEW_EVERY := 2
const SUMMARY_SECONDS := 3.0
const BALLOON_COLORS := [
	Color(0.9, 0.2, 0.25), Color(0.95, 0.8, 0.25), Color(0.25, 0.6, 0.85), Color(0.4, 0.75, 0.35), Color(0.75, 0.4, 0.85),
]

var reward_scale := 1.0
var _cfg: Dictionary
var _container: Node3D
var _balloons: Array = []
var _thrown := 0
var _pops := 0
var _darts_left := 0
var _phase := 0.0
var _power := 0.0
var _active := false
var _resolving := false
var _charging := false
var _dart: Node3D
var _velocity := Vector3.ZERO
var _flight_time := 0.0
var _travelled := 0.0
var _range := 0.0
var _falling := false
var _time := 0.0
var _dots: Array[MeshInstance3D] = []
var _dot_mat: StandardMaterial3D


func start(stall: Node3D, difficulty := 0) -> void:
	_cfg = DIFFICULTIES[difficulty]
	_darts_left = _cfg.darts
	_container = Node3D.new()
	stall.add_child(_container)
	_build_backdrop()
	_spawn_balloons()
	_build_preview()
	_active = true
	_emit_stats()


# Holding the left button raises the power from 0 to 1 and holds it at full; releasing throws the dart.
func _process(delta: float) -> void:
	_time += delta
	for b in _balloons:
		if not b.popped and is_instance_valid(b.node):
			b.node.position.y = b.base_y + sin(_time * 1.6 + b.phase) * 0.035
	if not _active or _resolving or not _charging:
		_show_preview(false)
		return
	_phase += delta * _cfg.bar_speed * CHARGE_RATE
	_power = minf(_phase, 1.0)
	power_changed.emit(_power)
	_update_preview()


func _unhandled_input(event: InputEvent) -> void:
	if not _active or _resolving:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_charging = true
			_phase = 0.0
			_power = 0.0
			power_changed.emit(0.0)
		elif not event.pressed and _charging:
			_charging = false
			_show_preview(false)
			_throw()
	elif event.is_action_pressed("interact"):
		_charging = false
		_finish()


func _spawn_balloons() -> void:
	for i in _cfg.darts:
		_spawn_balloon()


# Balloons hang at different depths, so how far the dart flies decides which ones it can reach.
func _spawn_balloon() -> void:
	var lpos := Vector3.ZERO
	for attempt in 40:
		lpos = Vector3(randf_range(SPAWN_X.x, SPAWN_X.y), randf_range(SPAWN_Y.x, SPAWN_Y.y), randf_range(SPAWN_Z.x, SPAWN_Z.y))
		var clear := true
		for other in _balloons:
			if not other.popped and other.node.position.distance_to(lpos) < MIN_BALLOON_GAP:
				clear = false
				break
		if clear:
			break
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = BALLOON_RADIUS
	sphere.height = BALLOON_RADIUS * 2.6
	mesh.mesh = sphere
	mesh.scale = Vector3.ONE * _cfg.balloon_scale
	var color: Color = BALLOON_COLORS[randi() % BALLOON_COLORS.size()]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.35
	mesh.material_override = mat
	mesh.position = lpos
	mesh.scale = Vector3.ONE * 0.01
	_container.add_child(mesh)
	create_tween().tween_property(mesh, "scale", Vector3.ONE * _cfg.balloon_scale, 0.25)
	var string := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.004
	cyl.bottom_radius = 0.004
	cyl.height = 0.4
	string.mesh = cyl
	var string_mat := StandardMaterial3D.new()
	string_mat.albedo_color = Color(0.95, 0.95, 0.9)
	string.material_override = string_mat
	string.position = Vector3(0, -BALLOON_RADIUS * 1.3 - 0.2, 0)
	mesh.add_child(string)
	var shine := MeshInstance3D.new()
	var shine_mesh := SphereMesh.new()
	shine_mesh.radius = BALLOON_RADIUS * 0.22
	shine_mesh.height = BALLOON_RADIUS * 0.44
	shine.mesh = shine_mesh
	var shine_mat := StandardMaterial3D.new()
	shine_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shine_mat.albedo_color = Color(1, 1, 1, 0.8)
	shine_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shine.material_override = shine_mat
	shine.position = Vector3(-BALLOON_RADIUS * 0.4, BALLOON_RADIUS * 0.55, BALLOON_RADIUS * 0.75)
	mesh.add_child(shine)
	_balloons.append({"node": mesh, "popped": false, "base_y": lpos.y, "phase": randf() * TAU, "color": color})


# The dart leaves the camera along the crosshair; power sets its speed and gravity bends the path.
func _throw() -> void:
	_resolving = true
	_thrown += 1
	_darts_left -= 1
	_flight_time = 0.0
	_travelled = 0.0
	_falling = false
	_range = _range_for(_power)
	dart_thrown.emit()

	var launch := _launch()
	var dir: Vector3 = launch[1]
	_velocity = dir * DART_SPEED

	_dart = MeshInstance3D.new()
	_dart.mesh = DART_MESH
	_container.add_child(_dart)
	_dart.global_position = launch[0]
	_dart.look_at(_dart.global_position + dir)


# Power decides how far the dart can fly before it drops.
func _range_for(power: float) -> float:
	return lerpf(MIN_RANGE, MAX_RANGE, power)


# Returns [start position, aim direction] for a dart thrown from the current camera.
func _launch() -> Array:
	var cam := get_viewport().get_camera_3d()
	var dir := -cam.global_transform.basis.z
	return [cam.global_position + dir * 0.4 + Vector3(0, -0.06, 0), dir]


func _is_blocked(world: Vector3) -> bool:
	var local := _container.to_local(world)
	return local.z <= WALL_Z or (local.y <= COUNTER_TOP and local.z < 0.9) or local.y <= 0.05


func _build_preview() -> void:
	_dot_mat = StandardMaterial3D.new()
	_dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dot_mat.albedo_color = Color(1, 1, 1, 0.9)
	_dot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dot_mat.no_depth_test = true
	var mesh := SphereMesh.new()
	mesh.radius = 0.018
	mesh.height = 0.036
	mesh.radial_segments = 8
	mesh.rings = 4
	for i in PREVIEW_DOTS:
		var dot := MeshInstance3D.new()
		dot.mesh = mesh
		dot.material_override = _dot_mat
		dot.visible = false
		_container.add_child(dot)
		_dots.append(dot)


func _show_preview(shown: bool) -> void:
	if not shown:
		for dot in _dots:
			dot.visible = false


# Simulates the dart with the same physics as the real throw and lays dots along the path.
func _update_preview() -> void:
	var launch := _launch()
	var pos: Vector3 = launch[0]
	var vel: Vector3 = launch[1] * DART_SPEED
	var reach := _range_for(_power)
	var travelled := 0.0
	var used := 0
	var step := 0
	var touches := false
	while used < _dots.size() and step * PREVIEW_STEP < MAX_FLIGHT:
		vel.y -= GRAVITY * PREVIEW_STEP
		var next := pos + vel * PREVIEW_STEP
		if _balloon_on_segment(pos, next) >= 0:
			touches = true
			break
		if _is_blocked(next):
			break
		travelled += pos.distance_to(next)
		if travelled >= reach:
			break
		pos = next
		step += 1
		if step % PREVIEW_EVERY == 0:
			_dots[used].global_position = pos
			_dots[used].visible = true
			used += 1
	for i in range(used, _dots.size()):
		_dots[i].visible = false
	_dot_mat.albedo_color = Color(0.4, 1.0, 0.5, 0.95) if touches else Color(1, 1, 1, 0.85)


func _physics_process(delta: float) -> void:
	if _dart == null:
		return
	var from := _dart.global_position
	_velocity.y -= GRAVITY * delta
	var to := from + _velocity * delta
	_flight_time += delta

	var popped_idx := _balloon_on_segment(from, to)
	if popped_idx >= 0:
		_dart.global_position = _container.to_global(_balloons[popped_idx].node.position)
		_land(popped_idx)
		return

	if not _falling:
		_travelled += from.distance_to(to)
		if _travelled >= _range:
			_falling = true
			_velocity = Vector3(0, minf(_velocity.y, 0.0), 0)
	_dart.global_position = to
	if not _falling and _velocity.length() > 0.1:
		_dart.look_at(to + _velocity)
	if _is_blocked(to) or _flight_time > MAX_FLIGHT:
		_land(-1)


# Union test: does the dart's path this frame touch any balloon that is still up?
func _balloon_on_segment(from: Vector3, to: Vector3) -> int:
	var seg := to - from
	var len_sq := maxf(seg.length_squared(), 0.000001)
	var reach: float = BALLOON_RADIUS * _cfg.balloon_scale * 1.15 + DART_TIP_RADIUS
	var best := -1
	var best_dist := reach
	for i in _balloons.size():
		if _balloons[i].popped:
			continue
		var center: Vector3 = _container.to_global(_balloons[i].node.position)
		var t := clampf((center - from).dot(seg) / len_sq, 0.0, 1.0)
		var dist := center.distance_to(from + seg * t)
		if dist <= best_dist:
			best_dist = dist
			best = i
	return best


func _land(popped_idx: int) -> void:
	_dart = null
	_show_preview(false)
	var hit := popped_idx >= 0
	if hit:
		_pops += 1
		_balloons[popped_idx].popped = true
		var node: Node3D = _balloons[popped_idx].node
		_burst(node.global_position, _balloons[popped_idx].color)
		var tween := create_tween()
		tween.tween_property(node, "scale", Vector3.ONE * 0.01, 0.12)
		tween.tween_callback(node.queue_free)
		if _darts_left > 0:
			_spawn_balloon()
	dart_resolved.emit(hit)
	_emit_stats()
	await get_tree().create_timer(0.6).timeout
	if not _active:
		return
	if _darts_left <= 0:
		_finish()
	else:
		_power = 0.0
		power_changed.emit(0.0)
		_resolving = false


func _burst(at: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 36
	p.lifetime = 0.9
	p.direction = Vector3(0, 0.4, 0.6)
	p.spread = 180.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.6
	p.gravity = Vector3(0, -4, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	p.mesh = quad
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.7, 0.08, 0.1), color, Color(0.3, 0.0, 0.05, 0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	p.color_ramp = ramp
	_container.add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


func _build_backdrop() -> void:
	var colors := [Color(0.62, 0.14, 0.17), Color(0.88, 0.82, 0.68)]
	var count := 12
	var width := 3.3 / count
	for i in count:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(width, 1.7, 0.02)
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i % 2]
		mat.emission_enabled = true
		mat.emission = colors[i % 2]
		mat.emission_energy_multiplier = 0.08
		mesh.material_override = mat
		mesh.position = Vector3(-1.65 + width * (i + 0.5), 1.7, WALL_Z + 0.02)
		_container.add_child(mesh)
	for side in [-1, 1]:
		var star := Label3D.new()
		star.text = "X"
		star.font_size = 200
		star.pixel_size = 0.004
		star.modulate = Color(0.6, 0.06, 0.06)
		star.outline_size = 12
		star.position = Vector3(side * 1.35, 1.2, WALL_Z + 0.04)
		_container.add_child(star)
	var title := Label3D.new()
	title.text = "POP THEM... OR JOIN THEM"
	title.font_size = 72
	title.pixel_size = 0.003
	title.modulate = Color(0.92, 0.86, 0.7)
	title.outline_modulate = Color(0.3, 0.02, 0.04)
	title.outline_size = 16
	title.position = Vector3(0, 2.38, WALL_Z + 0.04)
	_container.add_child(title)
	for x in [-1.2, -0.45, 0.3, 0.95, 1.4]:
		var h := randf_range(0.3, 0.9)
		var drip := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(0.035, h, 0.01)
		drip.mesh = dm
		var dmat := StandardMaterial3D.new()
		dmat.albedo_color = Color(0.45, 0.03, 0.04)
		drip.material_override = dmat
		drip.position = Vector3(x, 2.25 - h / 2, WALL_Z + 0.045)
		_container.add_child(drip)


func forfeit() -> void:
	_finish()


func _scaled(net: int) -> int:
	return maxi(roundi(net * reward_scale), 1) if net > 0 else net


func _current_net() -> int:
	return _scaled(_pops * _cfg.reward_per_pop - (_thrown - _pops) * _cfg.penalty_per_miss)


func _emit_stats() -> void:
	stats_changed.emit(_darts_left, _pops, _current_net())


# Quitting early counts every unthrown dart as a miss, so leaving can't dodge penalties.
func _finish() -> void:
	if not _active:
		return
	_active = false
	_charging = false
	_resolving = true
	_dart = null
	var misses: int = (_thrown - _pops) + _darts_left
	var net: int = _scaled(_pops * _cfg.reward_per_pop - misses * _cfg.penalty_per_miss)
	round_finished.emit(net, _pops, misses)
	await get_tree().create_timer(SUMMARY_SECONDS).timeout
	_container.queue_free()
	closed.emit()
