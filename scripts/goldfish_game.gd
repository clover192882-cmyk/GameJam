extends Node

const FX = preload("res://scripts/minigame_fx.gd")

signal round_finished(won: bool, net: int, catches: int)
signal closed

enum S { IDLE, QTE }

const ROUND_TIME := 45.0
const MAX_NETS := 3
const FAIL_COST := 20.0
const NET_BREAK_PENALTY := 4
const QTE_TIME := 3.0
const SUMMARY_SECONDS := 3.0
const BIG_BAR_WIDTH := 500.0
const BASIN_R := 3.7
const WATER_Y := 0.0
const SC := 0.24
const BASIN_POS := Vector3(0.0, 0.4, 0.0)
const RIM_Y := 0.35
var stand_offset := Vector3(0, 0.05, 2.05)
var view_pitch := deg_to_rad(-42)
const DIFF_MULT := [1.0, 2.0, 4.0]

const PROFILES := [
	{"fish_speed": 1.0, "zone_w": 0.18, "erratic": false, "small_swim": 1.0, "small_bonus": 0.0, "small_bar": 500.0,
		"small_scale": 1.0, "small_points": 1.0, "small_qte": 1.1, "big_qte": 1.1, "drift": 0.0,
		"small_stages": 2, "big_stages": 4},
	{"fish_speed": 1.3, "zone_w": 0.11, "erratic": false, "small_swim": 1.25, "small_bonus": 20.0, "small_bar": 320.0,
		"small_scale": 0.85, "small_points": 1.0, "small_qte": 1.1, "big_qte": 1.5, "drift": 0.5, "big_zone": 0.15,
		"small_stages": 3, "big_stages": 6},
	{"fish_speed": 1.6, "zone_w": 0.1, "erratic": true, "small_swim": 1.6, "small_bonus": 30.0, "small_bar": 320.0,
		"small_scale": 0.7, "small_points": 1.0, "small_qte": 1.1, "big_qte": 1.9, "drift": 0.9, "big_zone": 0.12,
		"small_stages": 4, "big_stages": 8},
]

const FISH_TYPES := [
	{"name": "Goldfish", "color": Color(1.0, 0.55, 0.1), "points": 2, "small": true,
		"model": "res://assets/models/goldfish_poly.glb", "length": 1.5, "flip": false, "tint": null},
	{"name": "Ribbon Fish", "color": Color(0.95, 0.9, 0.9), "points": 4, "small": false,
		"model": "res://assets/models/fish_poly.glb", "length": 2.3, "flip": false, "tint": null},
	{"name": "Black Fish", "color": Color(0.1, 0.1, 0.12), "points": 6, "small": false,
		"model": "res://assets/models/fish_quaternius.glb", "length": 2.5, "flip": false, "tint": Color(0.16, 0.16, 0.2)},
]

var reward_scale := 1.0
var state := S.IDLE
var time_left := ROUND_TIME
var nets_used := 0
var integrity := 100.0
var stage := 0
var ind := 0.0
var zone_c := 0.5
var zone_w := 0.18
var qte_left := QTE_TIME
var poi_pos := Vector2.ZERO
var dip := 0.0
var msg := ""
var msg_color := Color.WHITE
var msg_left := 0.0
var net := 0
var catches := 0

var _level := 0
var _prof: Dictionary = PROFILES[0]
var _holder: Node3D
var _fish: Array[Dictionary] = []
var _caught: Dictionary = {}
var _ind_dir := 1.0
var _zone_dir := 1.0
var _base_zone_w := 0.18
var _clock := 0.0
var _ambient_t := 0.0
var _thrash_t := 0.0
var _active := false
var _ripple_tex: GradientTexture2D
var _rng := RandomNumberGenerator.new()


func start(stall: Node3D, difficulty := 0) -> void:
	_level = clampi(difficulty, 0, PROFILES.size() - 1)
	_prof = PROFILES[_level]
	zone_w = _prof["zone_w"]
	_base_zone_w = zone_w
	_rng.randomize()
	_build_basin(stall)
	for i in _rng.randi_range(4, 6):
		_spawn_fish()
	_active = true


func hud() -> Dictionary:
	var small := _caught_small()
	return {
		"state": state, "time_left": time_left, "nets_left": MAX_NETS - nets_used, "max_nets": MAX_NETS,
		"integrity": integrity, "stage": stage, "stages": _stages(), "ind": _ind_display(), "zone_c": zone_c,
		"zone_w": zone_w, "qte_left": qte_left, "qte_time": QTE_TIME,
		"bar_w": _prof["small_bar"] if small else BIG_BAR_WIDTH, "msg": msg, "msg_color": msg_color,
		"msg_left": msg_left, "poi": poi_pos, "dip": dip, "net": net, "fail_cost": FAIL_COST,
	}


func forfeit() -> void:
	if not _active:
		return
	if state == S.QTE:
		net -= NET_BREAK_PENALTY
	_finish()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("interact"):
		forfeit()
		return
	if state == S.IDLE:
		var click: bool = event is InputEventMouseButton and event.pressed \
			and event.device != InputEvent.DEVICE_ID_EMULATION \
			and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		if click:
			_try_catch()
	elif event.is_action_pressed("minigame_action"):
		_qte_result(absf(_ind_display() - zone_c) <= zone_w / 2.0)


func _process(delta: float) -> void:
	if not _active:
		return
	_clock += delta
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_finish()
		return
	for f in _fish:
		_place_fish(f, delta)
	_update_fx(delta)
	dip = maxf(dip - delta, 0.0)
	msg_left = maxf(msg_left - delta, 0.0)
	var cam := get_viewport().get_camera_3d()
	if state == S.IDLE or _caught.is_empty():
		poi_pos = get_viewport().get_visible_rect().size / 2.0
		return
	poi_pos = cam.unproject_position(_holder.to_global(_caught["pos"])) + FX.shake_unit() * 14.0
	var small := _caught_small()
	var speed: float = _prof["small_qte"] if small else _prof["big_qte"]
	if not small and _prof["drift"] > 0.0:
		zone_c += _zone_dir * float(_prof["drift"]) * delta * 0.4
		var lo := zone_w / 2.0
		if zone_c >= 1.0 - lo:
			zone_c = 1.0 - lo
			_zone_dir = -1.0
		elif zone_c <= lo:
			zone_c = lo
			_zone_dir = 1.0
	if _prof["erratic"]:
		speed *= 1.0 + 0.9 * sin(_clock * 7.0) * cos(_clock * 3.1)
		speed = maxf(speed, 0.35)
	ind += _ind_dir * speed * delta
	if ind >= 1.0:
		ind = 1.0
		_ind_dir = -1.0
	elif ind <= 0.0:
		ind = 0.0
		_ind_dir = 1.0
	qte_left -= delta
	if qte_left <= 0.0:
		_qte_result(false)


# ------------------------------------------------------------------ scene

func _mat(color: Color, rough := 0.8, emissive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if emissive:
		m.emission_enabled = true
		m.emission = color
	return m


func _build_basin(stall: Node3D) -> void:
	_holder = Node3D.new()
	_holder.position = BASIN_POS
	_holder.scale = Vector3.ONE * SC
	stall.add_child(_holder)

	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = BASIN_R
	tm.outer_radius = BASIN_R + 0.45
	rim.mesh = tm
	rim.material_override = _mat(Color(0.55, 0.12, 0.1), 0.5)
	rim.position.y = RIM_Y
	rim.scale = Vector3(1, 0.9, 1)
	_holder.add_child(rim)

	var wall := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = BASIN_R + 0.2
	cm.bottom_radius = BASIN_R + 0.2
	cm.height = 1.65
	cm.cap_top = false
	cm.cap_bottom = false
	wall.mesh = cm
	var wall_mat := _mat(Color(0.5, 0.44, 0.36), 0.7)
	wall_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	wall.material_override = wall_mat
	wall.position.y = -0.475
	_holder.add_child(wall)

	var tray := MeshInstance3D.new()
	var trm := CylinderMesh.new()
	trm.top_radius = BASIN_R + 0.7
	trm.bottom_radius = BASIN_R + 0.7
	trm.height = 0.12
	tray.mesh = trm
	tray.material_override = _mat(Color(0.05, 0.04, 0.06), 0.9)
	tray.position.y = -1.36
	_holder.add_child(tray)

	var floor_m := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = BASIN_R
	fm.bottom_radius = BASIN_R
	fm.height = 0.05
	floor_m.mesh = fm
	floor_m.material_override = _mat(Color(0.12, 0.36, 0.46), 0.9)
	floor_m.position.y = -1.3
	_holder.add_child(floor_m)

	var water := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = BASIN_R
	wm.bottom_radius = BASIN_R
	wm.height = 0.04
	water.mesh = wm
	var wmat := _mat(Color(0.25, 0.6, 0.8, 0.12), 0.6)
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.emission_enabled = true
	wmat.emission = Color(0.03, 0.15, 0.2)
	water.material_override = wmat
	water.position.y = WATER_Y - 0.02
	_holder.add_child(water)

	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.1
	bulb_mesh.height = 0.2
	bulb_mesh.radial_segments = 8
	bulb_mesh.rings = 4
	var warm := _mat(Color(1.0, 0.8, 0.4), 0.3, true)
	var red := _mat(Color(1.0, 0.3, 0.25), 0.3, true)
	for i in 16:
		var a := TAU * i / 16.0
		var bulb := MeshInstance3D.new()
		bulb.mesh = bulb_mesh
		bulb.material_override = warm if i % 2 == 0 else red
		bulb.position = Vector3(cos(a), RIM_Y + 0.12, sin(a)) * (BASIN_R + 0.22)
		_holder.add_child(bulb)

	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.5)
	lamp.light_energy = 1.4
	lamp.omni_range = 3.0
	lamp.position = Vector3(0, 4.0, 0)
	_holder.add_child(lamp)

	_ripple_tex = GradientTexture2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.78, 0.9, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_ripple_tex.gradient = g
	_ripple_tex.fill = GradientTexture2D.FILL_RADIAL
	_ripple_tex.fill_from = Vector2(0.5, 0.5)
	_ripple_tex.fill_to = Vector2(1.0, 0.5)
	_ripple_tex.width = 64
	_ripple_tex.height = 64


func _mesh_aabb(node: Node, xf: Transform3D) -> AABB:
	var box := AABB()
	var has := false
	var here := xf
	if node is Node3D:
		here = xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		box = here * (node as MeshInstance3D).mesh.get_aabb()
		has = true
	for c in node.get_children():
		var sub := _mesh_aabb(c, here)
		if sub.size != Vector3.ZERO:
			box = box.merge(sub) if has else sub
			has = true
	return box


func _tint_meshes(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m is BaseMaterial3D:
				var d: BaseMaterial3D = m.duplicate()
				d.albedo_color = d.albedo_color * tint
				d.albedo_texture = null if tint.v < 0.3 else d.albedo_texture
				mi.set_surface_override_material(s, d)
	for c in node.get_children():
		_tint_meshes(c, tint)


func _find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null


func _make_fish_node(t: Dictionary) -> Node3D:
	var holder := Node3D.new()
	var wrap := Node3D.new()
	holder.add_child(wrap)
	var res: PackedScene = load(t["model"])
	var model: Node3D = res.instantiate()
	wrap.add_child(model)
	var box := _mesh_aabb(model, Transform3D.IDENTITY)
	var sz := box.size
	var rot := Basis.IDENTITY
	var long := maxf(sz.x, maxf(sz.y, sz.z))
	if long <= 0.0:
		long = 1.0
	if sz.z >= sz.x and sz.z >= sz.y:
		rot = Basis(Vector3.UP, PI / 2.0)
	elif sz.y >= sz.x and sz.y >= sz.z:
		rot = Basis(Vector3.BACK, -PI / 2.0)
	if t["flip"]:
		rot = Basis(Vector3.UP, PI) * rot
	var s: float = float(t["length"]) / long
	wrap.basis = rot * Basis.from_scale(Vector3.ONE * s)
	wrap.position = -(rot * (box.get_center() * s))
	if t["tint"] != null:
		_tint_meshes(model, t["tint"])
	var ap := _find_anim(model)
	if ap:
		var names := ap.get_animation_list()
		var pick := ""
		for n in names:
			if "swim" in String(n).to_lower():
				pick = n
		if pick == "" and names.size() > 0:
			pick = names[0]
		if pick != "":
			var an := ap.get_animation(pick)
			if an:
				an.loop_mode = Animation.LOOP_LINEAR
			ap.play(pick)
	holder.set_meta("animated", ap != null)
	return holder


func _spawn_fish() -> void:
	var roll := _rng.randi_range(1, 100)
	var ti := 0 if roll <= 60 else (1 if roll <= 88 else 2)
	var t: Dictionary = FISH_TYPES[ti]
	var node := _make_fish_node(t)
	if t["small"]:
		node.scale = Vector3.ONE * float(_prof["small_scale"])
	_holder.add_child(node)
	var f := {
		"type": ti,
		"c": Vector2(_rng.randf_range(-0.15, 0.15), _rng.randf_range(-0.15, 0.15)),
		"r": Vector2(_rng.randf_range(0.25, 0.6), _rng.randf_range(0.25, 0.6)),
		"a": _rng.randf() * TAU,
		"w": _rng.randf_range(0.5, 1.3) * (1.0 if _rng.randf() < 0.5 else -1.0),
		"depth": _rng.randf(),
		"pos": Vector3.ZERO,
		"caught": false,
		"node": node,
		"phase": _rng.randf() * TAU,
	}
	_fish.append(f)
	_place_fish(f, 0.0)


func _place_fish(f: Dictionary, delta: float) -> void:
	var a: float = f["a"]
	var r: Vector2 = f["r"]
	var c: Vector2 = f["c"]
	var w: float = f["w"]
	if not f["caught"]:
		var swim: float = _prof["small_swim"] if FISH_TYPES[f["type"]]["small"] else 1.0
		a += w * float(_prof["fish_speed"]) * swim * delta
		f["a"] = a
	var depth_y := WATER_Y - 0.2 - float(f["depth"]) * 0.3
	var p2 := (c + Vector2(cos(a) * r.x, sin(a) * r.y)) * BASIN_R
	var pos := Vector3(p2.x, depth_y, p2.y)
	f["pos"] = pos
	var tan2 := Vector2(-sin(a) * r.x, cos(a) * r.y) * signf(w)
	var target_yaw := atan2(-tan2.y, tan2.x)
	var node: Node3D = f["node"]
	var wag := 0.0
	var roll := 0.0
	if f["caught"]:
		pos.y = WATER_Y + 0.35 + sin(_clock * 14.0) * 0.07
		roll = sin(_clock * 20.0) * 0.5
		wag = sin(_clock * 26.0) * 0.35
	elif not node.get_meta("animated"):
		wag = sin(_clock * 7.0 + float(f["phase"])) * 0.16
	node.position = pos
	node.rotation = Vector3(roll, target_yaw + wag, 0.0)


# ------------------------------------------------------------------ rules

func _water_point() -> Variant:
	var cam := get_viewport().get_camera_3d()
	var center := get_viewport().get_visible_rect().size / 2.0
	var o: Vector3 = _holder.to_local(cam.project_ray_origin(center))
	var n: Vector3 = _holder.global_transform.basis.inverse() * cam.project_ray_normal(center)
	if n.y > -0.001:
		return null
	var t := (WATER_Y - o.y) / n.y
	return o + n * t


func _try_catch() -> void:
	dip = 0.3
	var wp = _water_point()
	if wp == null:
		_say("Nothing there...", Color(0.8, 0.8, 0.8))
		return
	_ripple(wp, Color(0.8, 0.95, 1.0), 0.9)
	var best: Dictionary = {}
	var best_d := INF
	for f in _fish:
		var reach := 0.95
		if FISH_TYPES[f["type"]]["small"]:
			reach += float(_prof["small_bonus"]) * 0.012
		var fp: Vector3 = f["pos"]
		var d := Vector2(wp.x - fp.x, wp.z - fp.z).length()
		if d < reach and d < best_d:
			best_d = d
			best = f
	if best.is_empty():
		_say("Nothing there...", Color(0.8, 0.8, 0.8))
		return
	best["caught"] = true
	_caught = best
	_splash(_surface(best["pos"]), FISH_TYPES[best["type"]]["color"], 0.7)
	state = S.QTE
	stage = 1
	_new_check()


func _surface(p: Vector3) -> Vector3:
	return Vector3(p.x, WATER_Y, p.z)


func _stages() -> int:
	return int(_prof["small_stages"]) if _caught_small() else int(_prof["big_stages"])


func _caught_small() -> bool:
	return not _caught.is_empty() and FISH_TYPES[_caught["type"]]["small"]


func _ind_display() -> float:
	return clampf(ind + FX.shake_unit().x * 0.03, 0.0, 1.0)


func _new_check() -> void:
	if _prof.has("big_zone"):
		zone_w = _prof["big_zone"] if not _caught_small() else _base_zone_w
	zone_c = _rng.randf_range(0.2, 0.8)
	ind = 0.0
	_ind_dir = 1.0
	qte_left = QTE_TIME


func _qte_result(hit: bool) -> void:
	if not hit:
		integrity -= FAIL_COST
	if integrity <= 0.0:
		_tear()
	elif stage >= _stages():
		_award()
	else:
		stage += 1
		_new_check()
		_say("Good!" if hit else "MISS  -%d%%" % int(FAIL_COST), Color(0.5, 1, 0.5) if hit else Color(1, 0.4, 0.3))


func _tear() -> void:
	net -= NET_BREAK_PENALTY
	_say("SCOOP TORN!  -%d" % NET_BREAK_PENALTY, Color(1, 0.3, 0.3))
	_splash(_surface(_caught["pos"]), Color(0.85, 0.3, 0.25), 1.0)
	FX.shake(self, get_viewport().get_camera_3d(), 0.02, 0.3)
	FX.flash(self, Color(1, 0.2, 0.15), 0.18, 0.3)
	_caught["caught"] = false
	_caught = {}
	state = S.IDLE
	nets_used += 1
	if nets_used >= MAX_NETS:
		_finish()
	else:
		integrity = 100.0


func _award() -> void:
	var t: Dictionary = FISH_TYPES[_caught["type"]]
	var base: float = t["points"]
	if t["small"]:
		base *= float(_prof["small_points"])
	var pts := maxi(roundi(base * integrity / 100.0 * DIFF_MULT[_level] * reward_scale), 1)
	net += pts
	catches += 1
	_say("Caught!  %+d" % pts, Color(1, 0.9, 0.3))
	var big: bool = not t["small"]
	var sp := _surface(_caught["pos"])
	_splash(sp, t["color"], 2.0 if big else 1.4)
	_burst(sp + Vector3(0, 0.6, 0), Color(1, 0.9, 0.4), 22 if big else 12, 3.0, 0.045, -2.0, 0.9)
	FX.ring(self, _holder.to_global(sp + Vector3(0, 0.6, 0)), Color(1, 0.9, 0.4), (1.6 if big else 1.0) * SC, 0.45)
	FX.shake(self, get_viewport().get_camera_3d(), 0.012 if big else 0.007, 0.25)
	FX.flash(self, Color(1, 0.95, 0.6), 0.16, 0.3)
	var node: Node3D = _caught["node"]
	var tw := create_tween()
	tw.tween_property(node, "position:y", WATER_Y + 1.6, 0.25).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(node, "scale", Vector3.ONE * 0.1, 0.3)
	tw.tween_callback(node.queue_free)
	_fish.erase(_caught)
	_spawn_fish()
	_caught = {}
	state = S.IDLE


func _finish() -> void:
	if not _active:
		return
	_active = false
	if not _caught.is_empty():
		_caught["caught"] = false
		_caught = {}
	state = S.IDLE
	round_finished.emit(net > 0, net, catches)
	await get_tree().create_timer(SUMMARY_SECONDS).timeout
	_holder.queue_free()
	closed.emit()


# -------------------------------------------------------------------- VFX

func _burst(pos: Vector3, color: Color, amount: int, speed: float, size: float, gravity: float, life: float, dir := Vector3.UP, spread := 180.0) -> void:
	FX.burst(self, _holder.to_global(pos), color, amount, speed * SC, size * SC * 1.5, gravity * SC, life, dir, spread)


func _ripple(pos: Vector3, color: Color, max_r := 1.0, delay := 0.0, dur := 0.9) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 2.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _ripple_tex
	mat.albedo_color = color
	quad.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.rotation_degrees.x = -90.0
	mi.scale = Vector3.ONE * 0.05
	mi.position = Vector3(pos.x, WATER_Y + 0.02, pos.z)
	_holder.add_child(mi)
	var tw := create_tween()
	if delay > 0.0:
		mi.visible = false
		tw.tween_interval(delay)
		tw.tween_callback(func(): mi.visible = true)
	tw.tween_property(mi, "scale", Vector3.ONE * max_r, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, dur)
	tw.tween_callback(mi.queue_free)


func _splash(pos: Vector3, tint: Color, power: float) -> void:
	var water := Color(0.75, 0.92, 1.0).lerp(tint, 0.25)
	_burst(pos + Vector3(0, 0.05, 0), water, int(26.0 * power), 3.2 * power, 0.04, -9.0, 0.8, Vector3.UP, 55.0)
	_burst(pos + Vector3(0, 0.05, 0), Color.WHITE, int(8.0 * power), 2.2 * power, 0.03, -9.0, 0.6, Vector3.UP, 70.0)
	for i in 3:
		_ripple(pos, Color(0.85, 0.95, 1.0, 0.9), (0.7 + 0.45 * i) * power, 0.09 * i)


func _update_fx(delta: float) -> void:
	_ambient_t -= delta
	if _ambient_t <= 0.0:
		_ambient_t = _rng.randf_range(0.5, 1.4)
		var a := _rng.randf() * TAU
		var rad := sqrt(_rng.randf()) * 0.85 * BASIN_R
		_ripple(Vector3(cos(a) * rad, 0, sin(a) * rad), Color(0.7, 0.9, 1.0, 0.45), _rng.randf_range(0.3, 0.6), 0.0, 1.2)
	if state == S.QTE and not _caught.is_empty():
		_thrash_t -= delta
		if _thrash_t <= 0.0:
			_thrash_t = _rng.randf_range(0.18, 0.32)
			_splash(_surface(_caught["pos"]), FISH_TYPES[_caught["type"]]["color"], 0.35)


func _say(text: String, color: Color) -> void:
	msg = text
	msg_color = color
	msg_left = 1.2
