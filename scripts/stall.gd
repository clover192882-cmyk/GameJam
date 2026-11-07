extends Node3D

const Build = preload("res://scripts/build.gd")

@export var stall_name := "Stall"
@export var color := Color(0.85, 0.2, 0.2)
@export var stall_id := ""

var unlocked: bool:
	get:
		return StallManager.is_unlocked(stall_id)

var _shutter: Node3D
var _lock_label: Label3D
var _light: OmniLight3D
var _light_base := 3.2
var _flicker_phase := 0.0
var _dolls: Array[Node3D] = []


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0 + _flicker_phase
	var f := 0.85 + 0.15 * sin(t * 13.0) * sin(t * 7.3)
	if fmod(t, 9.0) > 8.8:
		f *= 0.25
	_light.light_energy = _light_base * f
	for i in _dolls.size():
		_dolls[i].rotation.z = sin(t * 0.9 + i * 1.7) * 0.07


func _build_details(wood: Color, dark_color: Color, low := false) -> void:
	var rag := dark_color.darkened(0.2)
	var bone := Color(0.8, 0.76, 0.66)
	var blood := Color(0.38, 0.04, 0.04)

	# Tattered awning strips hanging unevenly from the roof front.
	for i in 9:
		var x := -1.7 + i * 0.425
		var h := randf_range(0.12, 0.35)
		var strip := Build.box(self, Vector3(x, 2.62 - h / 2, 1.2), Vector3(0.3, h, 0.03), rag if i % 2 == 0 else rag.lightened(0.12))
		strip.rotation.z = randf_range(-0.12, 0.12)

	# Cobwebs in the corners.
	var web := Color(0.8, 0.8, 0.78)
	for corner in [Vector3(-1.6, 2.5, 0.85), Vector3(1.6, 2.5, 0.85), Vector3(-1.6, 2.5, -1.1), Vector3(1.6, 2.5, -1.1)]:
		var sx := -signf(corner.x)
		for k in 4:
			var strand := Build.box(self, corner + Vector3(sx * 0.2, -0.2, 0), Vector3(0.012, 0.5 - k * 0.07, 0.012), web)
			strand.rotation.z = sx * (0.25 + k * 0.3)

	# Blood stains on the counter and sign.
	if low:
		Build.box(self, Vector3(-1.3, 0.085, 0.4), Vector3(0.5, 0.01, 0.4), blood)
		Build.box(self, Vector3(1.3, 0.085, -0.5), Vector3(0.3, 0.01, 0.25), blood)
	else:
		Build.box(self, Vector3(-0.7, 1.005, 0.55), Vector3(0.55, 0.01, 0.4), blood)
		Build.box(self, Vector3(0.9, 1.005, 0.7), Vector3(0.3, 0.01, 0.25), blood)
		Build.box(self, Vector3(-0.4, 0.55, 0.905), Vector3(0.08, 0.9, 0.01), blood)
		Build.box(self, Vector3(0.45, 0.7, 0.905), Vector3(0.05, 0.6, 0.01), blood)
	Build.box(self, Vector3(1.1, 2.05, 0.9), Vector3(0.06, 0.45, 0.01), blood)

	# Hanging dolls swaying in the draft, with glowing eyes.
	for x in [-1.45, 1.45]:
		var doll := Node3D.new()
		doll.position = Vector3(x, 2.6, 1.05)
		doll.scale = Vector3.ONE * 0.8
		add_child(doll)
		Build.box(doll, Vector3(0, -0.2, 0), Vector3(0.01, 0.4, 0.01), Color(0.2, 0.17, 0.12))
		Build.box(doll, Vector3(0, -0.5, 0), Vector3(0.18, 0.22, 0.1), Color(0.62, 0.5, 0.4))
		Build.box(doll, Vector3(0, -0.72, 0), Vector3(0.2, 0.22, 0.2), bone)
		Build.box(doll, Vector3(-0.045, -0.7, 0.105), Vector3(0.04, 0.04, 0.01), Color(1, 0.15, 0.08), false, 3.0)
		Build.box(doll, Vector3(0.045, -0.7, 0.105), Vector3(0.04, 0.04, 0.01), Color(1, 0.15, 0.08), false, 3.0)
		_dolls.append(doll)

	# Skull on a post and a row of jars on a shelf inside.
	var skull_y := 0.5 if low else 1.15
	Build.box(self, Vector3(-1.5, skull_y, 1.25 if low else 0.95), Vector3(0.14, 0.15, 0.14), bone)
	Build.box(self, Vector3(-1.5, skull_y - 0.05, 1.32 if low else 1.02), Vector3(0.1, 0.06, 0.02), Color(0.05, 0.03, 0.03))
	Build.box(self, Vector3(1.0, 1.7, -1.05), Vector3(1.4, 0.05, 0.25), wood)
	for j in 4:
		var jar := Build.box(self, Vector3(0.5 + j * 0.34, 1.82, -1.05), Vector3(0.14, 0.2, 0.14), Color(0.35, 0.55, 0.35, 1), false, 0.5)
		jar.rotation.y = randf() * 3.0

	# Rope, planks and nails on the front posts, plus broken fence boards beside the stall.
	for x in [-1.6, 1.6]:
		Build.box(self, Vector3(x, 1.5, 0.87), Vector3(0.16, 0.05, 0.05), Color(0.35, 0.28, 0.18))
	var board := Build.box(self, Vector3(-2.05, 0.5, 0.2), Vector3(0.08, 1.0, 0.3), wood)
	board.rotation.z = 0.25
	var board2 := Build.box(self, Vector3(2.05, 0.4, 0.4), Vector3(0.08, 0.8, 0.3), wood)
	board2.rotation.z = -0.35


# Goldfish stall: open front with a low rail and a tatami floor, so the basin sits on the ground.
func _build_low_front(wood: Color, dark_color: Color) -> void:
	var mat_c := Color(0.22, 0.24, 0.16)
	Build.box(self, Vector3(0, 0.04, 0.025), Vector3(3.4, 0.08, 2.45), mat_c)
	Build.box(self, Vector3(0, 0.081, 0.025), Vector3(3.4, 0.004, 0.06), dark_color.darkened(0.5))
	Build.box(self, Vector3(0, 0.081, -0.6), Vector3(3.4, 0.004, 0.06), dark_color.darkened(0.5))
	Build.box(self, Vector3(0, 0.081, 0.65), Vector3(3.4, 0.004, 0.06), dark_color.darkened(0.5))
	Build.box(self, Vector3(0, 0.35, 1.25), Vector3(3.5, 0.07, 0.09), wood, true)
	Build.box(self, Vector3(0, 0.17, 1.25), Vector3(3.5, 0.05, 0.07), wood, true)
	var barrier := StaticBody3D.new()
	var bshape := CollisionShape3D.new()
	var bbox := BoxShape3D.new()
	bbox.size = Vector3(3.5, 2.6, 0.1)
	bshape.shape = bbox
	barrier.add_child(bshape)
	barrier.position = Vector3(0, 1.3, 1.25)
	add_child(barrier)
	for sx in [-1.0, 1.0]:
		Build.box(self, Vector3(sx * 1.72, 0.25, 1.25), Vector3(0.12, 0.5, 0.12), wood, true)
		Build.box(self, Vector3(sx * 1.7, 0.35, 1.02), Vector3(0.08, 0.07, 0.5), wood, true)
		Build.box(self, Vector3(sx * 1.7, 0.17, 1.02), Vector3(0.07, 0.05, 0.5), wood, true)


func _ready() -> void:
	var wood := Color(0.4, 0.27, 0.16)
	var dark_color := color.darkened(0.15)

	Build.box(self, Vector3(0, 1.3, -1.2), Vector3(3.4, 2.6, 0.15), wood, true)
	var low := stall_id == "goldfish"
	if low:
		_build_low_front(wood, dark_color)
	else:
		Build.box(self, Vector3(0, 0.5, 0.6), Vector3(3.2, 1.0, 0.6), dark_color.darkened(0.2), true)
	Build.box(self, Vector3(-1.6, 1.3, 0.8), Vector3(0.12, 2.6, 0.12), wood, true)
	Build.box(self, Vector3(1.6, 1.3, 0.8), Vector3(0.12, 2.6, 0.12), wood, true)
	Build.box(self, Vector3(-1.7, 1.3, -0.2), Vector3(0.1, 2.6, 2.0), wood, true)
	Build.box(self, Vector3(1.7, 1.3, -0.2), Vector3(0.1, 2.6, 2.0), wood, true)
	Build.box(self, Vector3(0, 2.7, -0.2), Vector3(3.8, 0.15, 2.8), dark_color)

	_build_details(wood, dark_color, low)

	var sign_root := Node3D.new()
	sign_root.position = Vector3(0, 2.3, 0.85)
	sign_root.rotation.z = deg_to_rad(-3.0)
	add_child(sign_root)
	Build.box(sign_root, Vector3.ZERO, Vector3(2.7, 0.5, 0.08), Color(0.82, 0.74, 0.58), false, 0.15)
	Build.box(sign_root, Vector3(0, 0, -0.05), Vector3(2.8, 0.6, 0.04), wood)
	var sign_label := Label3D.new()
	sign_label.text = stall_name
	sign_label.font_size = 64
	sign_label.pixel_size = 0.0035
	sign_label.modulate = Color(0.45, 0.06, 0.06)
	sign_label.position = Vector3(0, 0, 0.06)
	sign_root.add_child(sign_label)

	Build.lantern(self, Vector3(-1.7, 2.35, 1.0), Color(1.0, 0.55, 0.2))
	Build.lantern(self, Vector3(1.7, 2.35, 1.0), Color(1.0, 0.55, 0.2))

	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.8, 1.9)
	light.light_color = Color(1.0, 0.75, 0.5)
	light.light_energy = 3.2
	light.omni_range = 7.0
	add_child(light)
	_light = light
	_light_base = light.light_energy
	_flicker_phase = randf() * 100.0

	# Covers only the counter, which the player's camera can never enter, so the ray always starts outside it.
	var area := Area3D.new()
	area.collision_layer = 2
	area.collision_mask = 0
	area.monitoring = false
	area.position = Vector3(0, 1.2, 0.6)
	var area_shape := CollisionShape3D.new()
	var area_box := BoxShape3D.new()
	area_box.size = Vector3(3.2, 2.0, 0.6)
	area_shape.shape = area_box
	area.add_child(area_shape)
	add_child(area)

	if low:
		_shutter = Build.box(self, Vector3(0, 1.4, 1.0), Vector3(3.1, 2.1, 0.08), Color(0.16, 0.12, 0.1))
	else:
		_shutter = Build.box(self, Vector3(0, 1.8, 0.62), Vector3(3.1, 1.6, 0.08), Color(0.16, 0.12, 0.1))
	_lock_label = Label3D.new()
	_lock_label.font_size = 56
	_lock_label.pixel_size = 0.005
	_lock_label.modulate = Color(0.92, 0.85, 0.6)
	_lock_label.position = Vector3(0, 0, 0.06)
	_shutter.add_child(_lock_label)

	light.visible = unlocked
	_refresh()
	StallManager.stall_unlocked.connect(_on_stall_unlocked)


func get_prompt() -> String:
	if unlocked:
		var level := DifficultyManager.selected(stall_id)
		var text := "[%s] Play %s - %s (x%.2f reward)" % [Settings.key_name("interact"), stall_name, DifficultyManager.level_name(level), DifficultyManager.reward_multiplier(stall_id, level)]
		if DifficultyManager.max_level(stall_id) > 0:
			text += "\n[%s] Change difficulty" % Settings.key_name("difficulty_cycle")
		var next_cost := DifficultyManager.next_unlock_cost(stall_id)
		if next_cost >= 0:
			var next_name := DifficultyManager.level_name(DifficultyManager.max_level(stall_id) + 1)
			if PointManager.can_afford(next_cost):
				text += "\n[%s] Unlock %s for %d points" % [Settings.key_name("difficulty_unlock"), next_name, next_cost]
			else:
				text += "\n%s needs %d points" % [next_name, next_cost + 1]
		return text
	var cost := StallManager.cost_of(stall_id)
	if PointManager.can_afford(cost):
		return "[%s] Unlock %s for %d points" % [Settings.key_name("interact"), stall_name, cost]
	return "%s locked - needs %d points" % [stall_name, cost + 1]


func _refresh() -> void:
	_shutter.visible = not unlocked
	_lock_label.text = "CLOSED\n%d pts" % StallManager.cost_of(stall_id)


func _on_stall_unlocked(id: String) -> void:
	if id != stall_id:
		return
	_refresh()
	for child in get_children():
		if child is OmniLight3D:
			child.visible = true
