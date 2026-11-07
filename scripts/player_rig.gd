extends Node3D

const SKIN := Color(0.86, 0.68, 0.56)
const SHIRT := Color(0.1, 0.17, 0.34)
const CUFF := Color(0.93, 0.9, 0.82)
const PANTS := Color(0.13, 0.13, 0.17)
const SHOE := Color(0.2, 0.14, 0.1)
const HAIR := Color(0.08, 0.06, 0.05)
const HIP_Y := 0.95
const THIGH := 0.46
const SHIN := 0.43
const FOOT := 0.06

class Leg:
	var hip: Node3D
	var knee: Node3D
	var foot: Node3D

class Arm:
	var side := 1.0
	var sh: Node3D
	var el: Node3D
	var wr: Node3D
	var fingers := []
	var thumb := []

static var _mats := {}

var third_person := false
var _head: Node3D
var _body: Node3D
var _spine: Node3D
var _head_vis: Node3D
var _legs: Array[Leg] = []
var _body_arms: Array[Arm] = []
var _body_meshes: Array[MeshInstance3D] = []

var _walk := 0.0
var _run := 0.0
var _air := 0.0
var _wind := 0.0
var _land := 0.0
var _t := 0.0


static func _mat(color: Color) -> StandardMaterial3D:
	if _mats.has(color):
		return _mats[color]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	m.disable_receive_shadows = true
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.35
	_mats[color] = m
	return m


func _joint(parent: Node3D, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	parent.add_child(j)
	return j


func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, body := false) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if body else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	if body:
		_body_meshes.append(mi)


func _build_arm(parent: Node3D, pos: Vector3, side: float, fp: bool) -> Arm:
	var a := Arm.new()
	a.side = side
	var b := not fp
	a.sh = _joint(parent, pos)
	_box(a.sh, Vector3(0, -0.15, 0), Vector3(0.095, 0.3, 0.095), SHIRT, b)
	a.el = _joint(a.sh, Vector3(0, -0.3, 0))
	_box(a.el, Vector3(0, -0.1, 0), Vector3(0.082, 0.2, 0.082), SHIRT, b)
	_box(a.el, Vector3(0, -0.205, 0), Vector3(0.094, 0.045, 0.094), CUFF, b)
	_box(a.el, Vector3(0, -0.255, 0), Vector3(0.066, 0.06, 0.066), SKIN, b)
	a.wr = _joint(a.el, Vector3(0, -0.28, 0))
	_box(a.wr, Vector3(0, -0.045, 0), Vector3(0.088, 0.09, 0.032), SKIN, b)
	if not fp:
		return a
	var lens := [0.05, 0.058, 0.054, 0.045]
	for j in 4:
		var l: float = lens[j if side > 0.0 else 3 - j]
		var base := _joint(a.wr, Vector3(-0.033 + j * 0.022, -0.09, 0))
		_box(base, Vector3(0, -l / 2.0, 0), Vector3(0.02, l, 0.02), SKIN)
		var tip := _joint(base, Vector3(0, -l, 0))
		_box(tip, Vector3(0, -l * 0.4, 0), Vector3(0.018, l * 0.8, 0.018), SKIN)
		a.fingers.append([base, tip])
	var tb := _joint(a.wr, Vector3(-side * 0.048, -0.025, 0))
	_box(tb, Vector3(0, -0.022, 0), Vector3(0.022, 0.045, 0.022), SKIN)
	var tt := _joint(tb, Vector3(0, -0.045, 0))
	_box(tt, Vector3(0, -0.018, 0), Vector3(0.02, 0.036, 0.02), SKIN)
	a.thumb = [tb, tt]
	return a


func setup(head: Node3D) -> void:
	_head = head
	_body = _joint(self, Vector3.ZERO)
	_box(_body, Vector3(0, HIP_Y + 0.03, 0), Vector3(0.34, 0.2, 0.2), PANTS, true)
	_spine = _joint(_body, Vector3(0, 1.0, 0))
	_box(_spine, Vector3(0, 0.28, 0), Vector3(0.4, 0.55, 0.22), SHIRT, true)
	_box(_spine, Vector3(0, 0.56, 0), Vector3(0.1, 0.1, 0.1), SKIN, true)
	_head_vis = _joint(_spine, Vector3(0, 0.6, 0))
	_box(_head_vis, Vector3(0, 0.06, 0), Vector3(0.2, 0.26, 0.22), SKIN, true)
	_box(_head_vis, Vector3(0, 0.17, 0.02), Vector3(0.22, 0.09, 0.24), HAIR, true)
	_box(_head_vis, Vector3(0, 0.06, 0.1), Vector3(0.22, 0.22, 0.05), HAIR, true)
	for s in [-1.0, 1.0]:
		_box(_head_vis, Vector3(s * 0.05, 0.08, -0.112), Vector3(0.035, 0.03, 0.01), Color(0.05, 0.05, 0.07), true)

	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var leg := Leg.new()
		leg.hip = _joint(_body, Vector3(side * 0.1, HIP_Y, 0))
		_box(leg.hip, Vector3(0, -THIGH / 2.0, 0), Vector3(0.16, THIGH, 0.17), PANTS, true)
		leg.knee = _joint(leg.hip, Vector3(0, -THIGH, 0))
		_box(leg.knee, Vector3(0, -SHIN / 2.0, 0), Vector3(0.14, SHIN, 0.15), PANTS, true)
		leg.foot = _joint(leg.knee, Vector3(0, -SHIN, 0))
		_box(leg.foot, Vector3(0, -FOOT / 2.0, -0.05), Vector3(0.13, FOOT, 0.27), SHOE, true)
		_legs.append(leg)
		_body_arms.append(_build_arm(_spine, Vector3(side * 0.29, 0.48, 0), side, false))

	set_third_person(false)


func head_offset() -> Vector3:
	return _head_vis.global_position - _head.global_position


func set_third_person(on: bool) -> void:
	third_person = on
	for m in _body_meshes:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func animate(delta: float, speed: float, sprinting: bool, on_floor: bool, vel_y: float, windup: float, landing: float, phase: float, active: bool, local_vel: Vector3) -> void:
	_t += delta
	_walk = lerpf(_walk, clampf(speed / 4.0, 0.0, 1.0) if on_floor else 0.0, minf(delta * 8.0, 1.0))
	_run = lerpf(_run, 1.0 if sprinting and speed > 4.5 else 0.0, minf(delta * 5.0, 1.0))
	_air = lerpf(_air, 0.0 if on_floor else 1.0, minf(delta * 12.0, 1.0))
	_wind = lerpf(_wind, 1.0 if windup >= 0.0 else 0.0, minf(delta * 18.0, 1.0))
	var land_target := clampf(landing / 0.15, 0.0, 1.0)
	_land = lerpf(_land, land_target, minf(delta * (24.0 if land_target > _land else 9.0), 1.0))
	var rise := _air * clampf(vel_y / 6.0, 0.0, 1.0)
	var fall := _air - rise

	_update_body(delta, speed, phase, local_vel, rise, fall)


func _update_body(delta: float, speed: float, phase: float, local_vel: Vector3, rise: float, fall: float) -> void:
	var dir := 1.0
	if local_vel.z > 0.1:
		dir = -1.0
	_body.rotation.y = 0.0

	var p := phase * dir
	var crouch := maxf(_wind, _land)
	var reach := []
	for i in 2:
		var ph := p + i * PI
		var t_ground := sin(ph) * lerpf(0.42, 0.85, _run) * _walk
		var f_ground := 0.06 + (lerpf(0.08, 0.3, _run) + lerpf(0.5, 1.3, _run) * maxf(0.0, cos(ph - 0.5))) * _walk
		var t_air := (0.75 if i == 0 else -0.2) * rise + (0.3 if i == 0 else 0.1) * fall
		var f_air := (1.1 if i == 0 else 0.7) * rise + 0.25 * fall
		var t := lerpf(t_ground, t_air, _air) + crouch * 0.85
		var fl := lerpf(f_ground, f_air, _air) + crouch * 1.6
		var leg := _legs[i]
		leg.hip.rotation.x = t
		leg.knee.rotation.x = -fl
		leg.foot.rotation.x = -(t - fl) * 0.85
		reach.append(THIGH * cos(t) + SHIN * cos(t - fl) + FOOT)
	_body.position.y = lerpf(maxf(reach[0], reach[1]) - HIP_Y, 0.0, _air)

	var s := sin(p)
	_spine.position.y = 1.0 + sin(_t * 1.7) * 0.004
	_spine.rotation = Vector3(
		-(0.04 + 0.26 * _run * _walk) - crouch * 0.3 - rise * 0.08,
		s * 0.13 * (0.6 + _run) * _walk,
		-s * 0.03 * _walk)

	_head_vis.rotation = Vector3(_head.rotation.x - _spine.rotation.x, -_spine.rotation.y, 0.0)

	for i in 2:
		var a := _body_arms[i]
		var swing := -sin(p + i * PI) * lerpf(0.4, 0.8, _run) * _walk
		var x_ground := -0.04 + swing + sin(_t * 1.7 + i) * 0.01
		var el_ground := 0.04 + 0.2 * _walk + 1.25 * _run * _walk + 0.4 * maxf(0.0, swing)
		var x := lerpf(x_ground, 2.5 * rise + 0.3 * fall, _air) - _wind * 0.9 + _land * 0.5
		var el := lerpf(el_ground, 0.35 * rise + 0.2 * fall, _air) + _land * 0.3
		a.sh.rotation = Vector3(x, 0.0, a.side * (0.03 + fall * 0.9 + _land * 0.35))
		a.el.rotation.x = el
