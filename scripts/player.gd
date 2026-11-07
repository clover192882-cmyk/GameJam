extends CharacterBody3D

const PlayerRig = preload("res://scripts/player_rig.gd")
const EYE_OFFSET := Vector3(0.0, 0.08, -0.22)

@export var move_speed := 4.0
@export var mouse_sensitivity := 0.0025
@export var gravity := 20.0
@export var sprint_speed := 7.0
@export var jump_velocity := 6.5
@export var double_tap_window := 0.3

@export var accel := 38.0
@export var sprint_accel := 14.0
@export var friction := 30.0
@export var jump_windup := 0.14
@export var bob_amount := 0.045
@export var sprint_fov_boost := 9.0

var _sprinting := false
var _jump_timer := -1.0
var _bob_phase := 0.0
var _bob_amp := 0.0
var _crouch := 0.0
var _land_dip := 0.0
var _land_hold := 0.0
var _air_vy := 0.0
var _was_on_floor := true
var _base_fov := 75.0
var fov_extra := 0.0
var _rig: Node3D
var _last_tap_key := KEY_NONE
var _last_tap_time := -10.0

var third_person := false
var _tp_blend := 0.0
var _cam_bob := Vector3.ZERO
var movement_enabled := true
var look_enabled := true

@onready var head: Node3D = $Head
@onready var interaction: Node = $Interaction
@onready var cam: Camera3D = $Head/Camera3D


func _ready() -> void:
	_register_input_actions()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_base_fov = cam.fov
	_rig = PlayerRig.new()
	add_child(_rig)
	_rig.setup(head)
	PointManager.game_over.connect(func(): movement_enabled = false)


func _unhandled_input(event: InputEvent) -> void:
	_detect_double_tap(event)
	if event.is_action_pressed("toggle_view") and not event.is_echo():
		toggle_view()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			look(event.relative)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var direction := Vector3.ZERO
	if movement_enabled:
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if input_dir == Vector2.ZERO:
			_sprinting = false
		if Input.is_action_just_pressed("jump") and is_on_floor() and _jump_timer < 0.0:
			_jump_timer = jump_windup
	else:
		_sprinting = false
		_jump_timer = -1.0

	if _jump_timer >= 0.0:
		_jump_timer -= delta
		if _jump_timer < 0.0 and is_on_floor():
			velocity.y = jump_velocity

	var speed := sprint_speed if _sprinting else move_speed
	var target := direction * speed
	var horiz := Vector3(velocity.x, 0, velocity.z)
	var rate := friction if direction == Vector3.ZERO else (sprint_accel if _sprinting else accel)
	horiz = horiz.move_toward(target, rate * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z
	move_and_slide()

	_update_camera(delta, horiz.length())


func _update_camera(delta: float, speed: float) -> void:
	var on_floor := is_on_floor()
	if not on_floor:
		_air_vy = velocity.y
	elif not _was_on_floor:
		_land_dip = clampf(absf(_air_vy) / 14.0 + 0.12, 0.2, 0.28)
		_land_hold = 0.12
	_was_on_floor = on_floor

	var moving := on_floor and movement_enabled and speed > 0.3
	var amp_target := 0.0
	if moving:
		amp_target = bob_amount * clampf(speed / move_speed, 0.0, 1.8)
		_bob_phase += delta * speed * 2.3
	_bob_amp = lerpf(_bob_amp, amp_target, minf(delta * 10.0, 1.0))

	var crouch_target := 0.0
	if _jump_timer >= 0.0:
		crouch_target = 0.28
	_crouch = lerpf(_crouch, crouch_target, minf(delta * 16.0, 1.0))
	if _land_hold > 0.0:
		_land_hold -= delta
	else:
		_land_dip = lerpf(_land_dip, 0.0, minf(delta * 7.0, 1.0))

	var offset := Vector3(sin(_bob_phase) * _bob_amp * 0.6, absf(sin(_bob_phase)) * _bob_amp - _bob_amp * 0.5, 0.0)
	offset.y -= _crouch + _land_dip
	if not movement_enabled and _jump_timer < 0.0:
		offset = Vector3.ZERO
		_crouch = 0.0
		_land_dip = 0.0
		_land_hold = 0.0
	_cam_bob = _cam_bob.lerp(offset, minf(delta * 20.0, 1.0))
	cam.position = _cam_bob
	cam.rotation.z = lerpf(cam.rotation.z, -sin(_bob_phase) * _bob_amp * 0.25 if moving else 0.0, minf(delta * 8.0, 1.0))

	var fov_target := _base_fov + fov_extra + (sprint_fov_boost if _sprinting and speed > move_speed else 0.0)
	cam.fov = lerpf(cam.fov, fov_target, minf(delta * 6.0, 1.0))
	var local_vel := transform.basis.inverse() * velocity
	_rig.animate(delta, speed, _sprinting, on_floor, velocity.y, _jump_timer, _land_dip, _bob_phase, movement_enabled, local_vel)
	_update_view(delta)


func toggle_view() -> void:
	third_person = not third_person


func _update_view(delta: float) -> void:
	var want := third_person and movement_enabled
	_tp_blend = lerpf(_tp_blend, 1.0 if want else 0.0, minf(delta * 8.0, 1.0))
	var rig_tp := _tp_blend > 0.5
	if rig_tp != _rig.third_person:
		_rig.set_third_person(rig_tp)
	var arm := Vector3.ZERO
	if _tp_blend > 0.001:
		var dir := head.global_transform.basis * Vector3(0.45, 0.35, 1.0).normalized()
		var dist := 3.2
		var q := PhysicsRayQueryParameters3D.create(head.global_position, head.global_position + dir * dist, 1)
		q.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			dist = maxf(head.global_position.distance_to(hit.position) - 0.2, 0.3)
		arm = head.global_transform.basis.inverse() * (dir * dist) * _tp_blend
	var body_move: Vector3 = head.global_transform.basis.inverse() * _rig.head_offset()
	cam.position = Vector3(_cam_bob.x, 0.0, 0.0) + body_move + arm + EYE_OFFSET
	var ray := get_node_or_null("Head/Camera3D/InteractRay")
	if ray:
		ray.position = -arm


func look(relative: Vector2) -> void:
	if not look_enabled:
		return
	rotate_y(-relative.x * mouse_sensitivity)
	head.rotate_x(-relative.y * mouse_sensitivity)
	head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))


func set_sprint(on: bool) -> void:
	_sprinting = on and movement_enabled


func _detect_double_tap(event: InputEvent) -> void:
	if not movement_enabled or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if key != KEY_W and key != KEY_A and key != KEY_S and key != KEY_D:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if key == _last_tap_key and now - _last_tap_time <= double_tap_window:
		_sprinting = true
	_last_tap_key = key
	_last_tap_time = now


func lock_view(pos: Vector3, yaw: float, pitch: float, allow_look := false) -> void:
	movement_enabled = false
	look_enabled = allow_look
	velocity = Vector3.ZERO
	global_position = pos
	rotation.y = yaw
	head.rotation.x = pitch


func unlock_view() -> void:
	look_enabled = true
	movement_enabled = not PointManager.is_game_over


func _register_input_actions() -> void:
	var keys := {
		"move_forward": KEY_W,
		"move_back": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"interact": KEY_E,
		"minigame_action": KEY_SPACE,
		"jump": KEY_SPACE,
		"difficulty_cycle": KEY_Q,
		"difficulty_unlock": KEY_R,
		"toggle_view": KEY_V,
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[action]
		InputMap.action_add_event(action, ev)
