extends Node

const FX = preload("res://scripts/minigame_fx.gd")

signal shot_fired(hit: bool)
signal reload_started
signal round_finished(won: bool, net: int, hits: int)
signal closed

const ROUND_TIME := 30.0
const MAX_AMMO := 6
const RELOAD_TIME := 1.0
const SUMMARY_SECONDS := 3.0
const TARGET_LAYER := 4
const RANGE := 8.0
const SC := 0.22
const GUN_REST := Vector3(0.32, -0.28, -0.65)
const HOLDER_POS := Vector3(0.0, 1.0, 0.2)
const LANE_Y := [0.6, 1.9, 3.2]
const LANE_Z := [-2.5, -3.5, -4.5]
const LANE_HALF := 7.0
const POOL_SIZE := 12
const KINDS := {
	"standard": {"speed": 3.0, "color": Color(1.0, 0.85, 0.1), "scale": 1.0},
	"gold": {"speed": 6.0, "color": Color(1.0, 0.55, 0.0), "scale": 0.8},
	"skull": {"speed": 3.5, "color": Color(0.1, 0.1, 0.13), "scale": 1.1},
}
const POINTS := [
	{"standard": 3, "gold": 6, "skull": -8},
	{"standard": 6, "gold": 12, "skull": -16},
	{"standard": 12, "gold": 30, "skull": -36},
]
const MISS_PENALTY := [2, 4, 8]
const WEIGHTS := [[0.6, 0.2, 0.2], [0.4, 0.2, 0.4], [0.2, 0.15, 0.65]]
const SPEED_MULT := [0.7, 1.4, 2.3]

const C_RED := Color(0.5, 0.09, 0.12)
const C_DARK_RED := Color(0.28, 0.04, 0.07)
const C_CREAM := Color(0.62, 0.57, 0.48)
const C_GOLD := Color(0.95, 0.75, 0.2)
const BUNTING := [
	Color(0.98, 0.85, 0.2), Color(0.95, 0.35, 0.6), Color(0.45, 0.8, 0.3),
	Color(0.3, 0.6, 0.95), Color(0.98, 0.55, 0.15), Color(0.6, 0.3, 0.8),
]

var reward_scale := 1.0
var ammo := MAX_AMMO
var reloading := false
var time_left := ROUND_TIME
var net := 0
var hits := 0

var _level := 0
var _holder: Node3D
var _pool: Array[Dictionary] = []
var _lane_timers: Array[float] = [0.0, 0.7, 1.4]
var _active := false
var _rng := RandomNumberGenerator.new()
var _shared := {}
var _gun: Node3D


func start(stall: Node3D, difficulty := 0) -> void:
	_level = clampi(difficulty, 0, 2)
	_rng.randomize()
	_holder = Node3D.new()
	_holder.position = HOLDER_POS
	_holder.scale = Vector3.ONE * SC
	stall.add_child(_holder)
	_build_backdrop()
	_build_lanes()
	_build_decor()
	for i in POOL_SIZE:
		_make_duck()
	_build_gun()
	_active = true


func _build_gun() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_gun = Node3D.new()
	_gun.position = GUN_REST
	cam.add_child(_gun)
	var rifle: Node3D = load("res://assets/models/rifle.glb").instantiate()
	rifle.scale = Vector3.ONE * 0.55
	rifle.rotation_degrees = Vector3(0, 0, -90)
	rifle.position = Vector3(0, 0.04, -0.28)
	_gun.add_child(rifle)


func _gun_recoil() -> void:
	if not is_instance_valid(_gun):
		return
	_gun.position = GUN_REST + Vector3(0, 0.02, 0.1)
	_gun.rotation.x = 0.18
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_gun, "position", GUN_REST, 0.14)
	tw.tween_property(_gun, "rotation:x", 0.0, 0.14)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.4)
	light.light_energy = 3.0
	light.omni_range = 5.0
	_gun.add_child(light)
	light.position = Vector3(0, 0, -0.9)
	var lt := create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.1)
	lt.tween_callback(light.queue_free)


func hud() -> Dictionary:
	return {"time_left": time_left, "ammo": ammo, "max_ammo": MAX_AMMO, "reloading": reloading, "net": net, "hits": hits}


func forfeit() -> void:
	_finish()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("interact"):
		_finish()
		return
	if event.is_action_pressed("difficulty_unlock"):
		_reload()
		return
	if event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_shoot()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_reload()


func _process(delta: float) -> void:
	if not _active:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_finish()
		return
	for lane in 3:
		_lane_timers[lane] -= delta
		if _lane_timers[lane] <= 0.0:
			_spawn_duck(lane)
			_lane_timers[lane] = _rng.randf_range(1.2, 2.4)
	_move_ducks(delta)


# ------------------------------------------------------------------ scene

func _mat(color: Color, emissive := false) -> StandardMaterial3D:
	var key := [color, emissive]
	if _shared.has(key):
		return _shared[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.7
	if emissive:
		m.emission_enabled = true
		m.emission = color
	_shared[key] = m
	return m


func _sphere(radius: float) -> SphereMesh:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	return sm


func _box_mesh(size: Vector3) -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = size
	return bm


func _add(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _box(pos: Vector3, size: Vector3, color: Color, emissive := false) -> void:
	_add(_holder, _box_mesh(size), pos, _mat(color, emissive))


func _build_backdrop() -> void:
	_box(Vector3(0, 2.5, -5.5), Vector3(17, 7.5, 0.3), Color(0.05, 0.1, 0.2))
	for i in range(-8, 9, 2):
		_box(Vector3(i, 2.5, -5.35), Vector3(0.05, 7.5, 0.05), Color(0.03, 0.06, 0.13))
	var mountain := _mat(Color(0.04, 0.09, 0.17))
	for x in [-5.0, -1.5, 2.5, 6.0]:
		_add(_holder, _box_mesh(Vector3(3.5, 3.5, 0.1)), Vector3(x, 0.3, -5.3), mountain, Vector3(0, 0, PI / 4.0))
	var cloud := StandardMaterial3D.new()
	cloud.albedo_color = Color(0.35, 0.4, 0.55)
	cloud.emission_enabled = true
	cloud.emission = Color(0.35, 0.4, 0.55)
	cloud.emission_energy_multiplier = 0.3
	var puff := _sphere(0.8)
	for c in [Vector3(-4, 4.7, -5.2), Vector3(2.5, 5.0, -5.2), Vector3(6, 4.4, -5.2)]:
		for o in [Vector3(-0.8, 0, 0), Vector3(0, 0.3, 0), Vector3(0.8, 0, 0)]:
			_add(_holder, puff, c + o, cloud, Vector3.ZERO, Vector3(1.3, 0.8, 0.2))


func _build_lanes() -> void:
	var wave := _sphere(0.6)
	var front := _mat(Color(0.35, 0.5, 0.62))
	var back := _mat(Color(0.07, 0.2, 0.3))
	for i in 3:
		var y: float = LANE_Y[i]
		var z: float = LANE_Z[i]
		_box(Vector3(0, y - 0.62, z + 0.2), Vector3(16, 0.12, 0.9), Color(0.04, 0.1, 0.17))
		for k in 17:
			var x := -8.0 + k
			_add(_holder, wave, Vector3(x, y - 0.42 + 0.04 * (k % 2), z + 0.4), front, Vector3.ZERO, Vector3(1.0, 0.45, 0.3))
			_add(_holder, wave, Vector3(x + 0.5, y - 0.55, z + 0.3), back, Vector3.ZERO, Vector3(1.0, 0.45, 0.3))


func _build_decor() -> void:
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.76, 0.45)
	lamp.light_energy = 1.6
	lamp.omni_range = 4.5
	lamp.position = Vector3(0, 2.5, 3.0)
	_holder.add_child(lamp)
	var prism := PrismMesh.new()
	prism.size = Vector3(0.6, 0.7, 0.05)
	for k in 16:
		var frac := fmod(k, 4.0) / 4.0
		var y := 4.2 - 0.3 * sin(PI * frac)
		_add(_holder, prism, Vector3(-7.0 + k * 0.95, y, -1.2), _mat(BUNTING[k % BUNTING.size()].darkened(0.45)), Vector3(0, 0, PI))
	var bulb := _sphere(0.1)
	for k in 17:
		var bc: Color = [Color(1, 0.3, 0.3), Color(1, 0.9, 0.4), Color(0.4, 0.7, 1)][k % 3]
		_add(_holder, bulb, Vector3(-8.0 + k, 4.55, -1.0), _mat(Color(1.0, 0.76, 0.38) if k % 2 == 0 else Color(1.0, 0.3, 0.25), true))
	for sx in [-1.0, 1.0]:
		for f in 5:
			_box(Vector3(sx * (7.6 + f * 0.0), 1.5 + f * 0.9, -2.0), Vector3(0.7, 0.8, 0.9), C_RED if f % 2 == 0 else C_CREAM)
	var curtain_l := _mat(C_DARK_RED)
	for sx in [-1.0, 1.0]:
		for f in 4:
			_add(_holder, _box_mesh(Vector3(0.4, 5.2, 0.25)), Vector3(sx * (6.7 + f * 0.0 + (f % 2) * 0.0), 2.2, -1.5 - f * 0.45), curtain_l if f % 2 == 0 else _mat(C_RED))


func _make_duck() -> void:
	var body := StaticBody3D.new()
	body.visible = false
	body.collision_layer = TARGET_LAYER
	body.collision_mask = 0
	body.process_mode = Node.PROCESS_MODE_DISABLED
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.YELLOW
	mat.roughness = 0.7
	var beak := StandardMaterial3D.new()
	beak.albedo_color = Color(1.0, 0.5, 0.05)
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(0.02, 0.02, 0.02)
	eye.emission = Color(1.0, 0.1, 0.1)
	var parts := Node3D.new()
	body.add_child(parts)
	_add(parts, _sphere(0.4), Vector3.ZERO, mat, Vector3.ZERO, Vector3(1.3, 1.0, 0.8))
	_add(parts, _sphere(0.24), Vector3(0.42, 0.5, 0), mat)
	_add(parts, _sphere(0.16), Vector3(-0.52, 0.3, 0), mat, Vector3.ZERO, Vector3(1.2, 1.0, 0.6))
	_add(parts, _box_mesh(Vector3(0.22, 0.08, 0.2)), Vector3(0.66, 0.46, 0), beak)
	for s in [-1.0, 1.0]:
		_add(parts, _sphere(0.045), Vector3(0.55, 0.58, s * 0.17), eye)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 56
	label.pixel_size = 0.006
	label.outline_size = 14
	label.position = Vector3(0, 1.0, 0)
	body.add_child(label)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 1.2, 0.8)
	cs.shape = shape
	cs.position = Vector3(0.1, 0.3, 0)
	body.add_child(cs)
	_holder.add_child(body)
	var d := {"node": body, "mat": mat, "beak": beak, "eye": eye, "label": label,
		"active": false, "kind": "standard", "dir": 1.0, "speed": 3.0,
		"t": 0.0, "phase": 0.0, "lane_y": 1.0, "base_scale": 1.0}
	body.set_meta("duck", d)
	_pool.append(d)


# ------------------------------------------------------------------ rules

func _spawn_duck(lane: int) -> void:
	for d in _pool:
		if d["active"]:
			continue
		var roll := _rng.randf()
		var w: Array = WEIGHTS[_level]
		var kind := "standard" if roll < w[0] else ("gold" if roll < w[0] + w[1] else "skull")
		var info: Dictionary = KINDS[kind]
		var dir := 1.0 if lane % 2 == 0 else -1.0
		var node: StaticBody3D = d["node"]
		d["active"] = true
		d["kind"] = kind
		d["dir"] = dir
		d["speed"] = float(info["speed"]) * SPEED_MULT[_level]
		d["t"] = 0.0
		d["phase"] = _rng.randf() * TAU
		d["lane_y"] = LANE_Y[lane]
		d["base_scale"] = info["scale"]
		d["mat"].albedo_color = info["color"]
		d["beak"].albedo_color = Color(0.9, 0.1, 0.1) if kind == "gold" else Color(1.0, 0.5, 0.05)
		d["eye"].emission_enabled = kind == "skull"
		var lbl: Label3D = d["label"]
		lbl.text = "%+d" % POINTS[_level][kind]
		lbl.modulate = Color(1, 0.35, 0.35) if kind == "skull" else (Color(1, 0.9, 0.3) if kind == "gold" else Color.WHITE)
		node.scale = Vector3.ONE * 0.02
		node.position = Vector3(-(LANE_HALF + 0.8) * dir, LANE_Y[lane], LANE_Z[lane])
		node.rotation.y = 0.0 if dir > 0.0 else PI
		node.visible = true
		node.process_mode = Node.PROCESS_MODE_INHERIT
		return


func _move_ducks(delta: float) -> void:
	for d in _pool:
		if not d["active"]:
			continue
		var node: StaticBody3D = d["node"]
		d["t"] += delta
		node.position.x += d["dir"] * d["speed"] * delta
		node.position.y = d["lane_y"] + sin(d["t"] * 3.0 + d["phase"]) * 0.05
		var m := clampf((LANE_HALF + 0.8 - absf(node.position.x)) / 1.5, 0.02, 1.0)
		node.scale = Vector3.ONE * d["base_scale"] * m
		if absf(node.position.x) > LANE_HALF + 1.0:
			_release(d)


func _release(d: Dictionary) -> void:
	d["active"] = false
	d["node"].visible = false
	d["node"].process_mode = Node.PROCESS_MODE_DISABLED


func _shoot() -> void:
	if reloading:
		return
	var center := get_viewport().get_visible_rect().size / 2.0
	if ammo <= 0:
		_reload()
		return
	ammo -= 1
	_gun_recoil()
	var cam := get_viewport().get_camera_3d()
	var from := cam.global_position
	var sway := FX.shake_unit() * 0.012
	var dir := (-cam.global_transform.basis.z + cam.global_transform.basis.x * sway.x + cam.global_transform.basis.y * sway.y).normalized()
	var to := from + dir * RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to, TARGET_LAYER)
	var result := cam.get_world_3d().direct_space_state.intersect_ray(query)
	var hit := false
	if not result.is_empty() and result.collider.has_meta("duck"):
		var d: Dictionary = result.collider.get_meta("duck")
		if d["active"]:
			hit = true
			hits += 1
			var pts: int = POINTS[_level][d["kind"]]
			if pts > 0:
				pts = maxi(roundi(pts * reward_scale), 1)
			net += pts
			FX.popup_2d(self, center + Vector2(10, -30), "%+d" % pts, Color(0.4, 1, 0.4) if pts > 0 else Color(1, 0.3, 0.3))
			_hit_effect(result.position, d["kind"], pts > 0, cam)
			_release(d)
	if not hit:
		var lost: int = MISS_PENALTY[_level]
		net -= lost
		FX.popup_2d(self, center + Vector2(10, -30), "-%d MISS" % lost, Color(1, 0.5, 0.3))
		FX.flash(self, Color(1, 0.2, 0.1), 0.08, 0.2)
	shot_fired.emit(hit)
	if ammo <= 0:
		FX.popup_2d(self, center + Vector2(-40, 30), "RELOAD!  (R / right click)", Color(1, 0.8, 0.3))


func _hit_effect(pos: Vector3, kind: String, good: bool, cam: Camera3D) -> void:
	var col: Color = KINDS[kind]["color"]
	FX.burst(self, pos, col, 22, 1.2, 0.015, -1.5, 0.8)
	FX.burst(self, pos, Color.WHITE, 8, 1.4, 0.01, -1.0, 0.5)
	FX.ring(self, pos, Color(0.5, 1.0, 0.5) if good else Color(1.0, 0.3, 0.3), 0.35, 0.35)
	if kind == "gold":
		FX.burst(self, pos, Color(1, 0.95, 0.4), 18, 1.6, 0.012, -0.8, 1.0)
	elif kind == "skull":
		FX.burst(self, pos, Color(0.5, 0.1, 0.1), 14, 0.8, 0.02, 0.4, 0.8)
		FX.flash(self, Color(0.6, 0.0, 0.0), 0.2, 0.3)
	FX.shake(self, cam, 0.004, 0.15)


func _reload() -> void:
	if reloading or ammo == MAX_AMMO or not _active:
		return
	reloading = true
	reload_started.emit()
	_gun_reload_spin()
	await get_tree().create_timer(RELOAD_TIME).timeout
	ammo = MAX_AMMO
	reloading = false


func _gun_reload_spin() -> void:
	if not is_instance_valid(_gun):
		return
	var tw := create_tween()
	tw.tween_property(_gun, "rotation:x", -TAU, RELOAD_TIME * 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): _gun.rotation.x = 0.0)


func _finish() -> void:
	if not _active:
		return
	_active = false
	round_finished.emit(net > 0, net, hits)
	await get_tree().create_timer(SUMMARY_SECONDS).timeout
	if is_instance_valid(_gun):
		_gun.queue_free()
	_holder.queue_free()
	closed.emit()
