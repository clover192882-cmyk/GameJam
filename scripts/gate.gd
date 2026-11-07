extends Node3D

const Build = preload("res://scripts/build.gd")

const OPENING_HALF := 2.0
const PILLAR := 0.6
const DOOR_HEIGHT := 3.4
const BAR_STEP := 0.22
const IRON := Color(0.07, 0.07, 0.09)
const STONE := Color(0.42, 0.4, 0.38)
const LOCKED_COLOR := Color(1.0, 0.35, 0.2)
const OPEN_COLOR := Color(0.5, 1.0, 0.6)

var unlocked: bool:
	get:
		return StallManager.gate_open

var _doors: Array[Node3D] = []
var _blocker: CollisionShape3D
var _lock: Node3D
var _lock_label: Label3D
var _sign: Label3D
var _light: OmniLight3D
var _exit_light: OmniLight3D
var _iron_mat: StandardMaterial3D
var _tip_mesh: CylinderMesh


func _ready() -> void:
	add_to_group("gate")
	_iron_mat = StandardMaterial3D.new()
	_iron_mat.albedo_color = IRON
	_tip_mesh = CylinderMesh.new()
	_tip_mesh.top_radius = 0.0
	_tip_mesh.bottom_radius = 0.045
	_tip_mesh.height = 0.22

	_build_frame()
	_doors.append(_build_door(-1.0))
	_doors.append(_build_door(1.0))
	_build_lock()
	_build_blocker()
	_build_areas()
	_build_exit_path()

	_light = OmniLight3D.new()
	_light.position = Vector3(-1.5, 3.5, 0)
	_light.light_color = LOCKED_COLOR
	_light.light_energy = 2.5
	_light.omni_range = 9.0
	add_child(_light)

	_exit_light = OmniLight3D.new()
	_exit_light.position = Vector3(3.0, 2.5, 0)
	_exit_light.light_color = OPEN_COLOR
	_exit_light.light_energy = 2.0
	_exit_light.omni_range = 7.0
	_exit_light.visible = false
	add_child(_exit_light)

	StallManager.gate_opened.connect(_on_gate_opened.bind(true))
	if StallManager.gate_open:
		_on_gate_opened(false)


func get_prompt() -> String:
	if unlocked:
		return "The gate is open - step outside to leave"
	if PointManager.can_afford(StallManager.GATE_COST):
		return "[E] Unlock the gate for %d points" % StallManager.GATE_COST
	return "The gate is locked - needs %d points" % (StallManager.GATE_COST + 1)


func interact() -> void:
	StallManager.try_open_gate()


func _build_frame() -> void:
	for side in [-1.0, 1.0]:
		var z: float = side * (OPENING_HALF + PILLAR / 2.0)
		Build.box(self, Vector3(0, 2.6, z), Vector3(PILLAR, 5.2, PILLAR), STONE)
		Build.box(self, Vector3(0, 5.3, z), Vector3(PILLAR + 0.2, 0.2, PILLAR + 0.2), STONE)
		Build.lantern(self, Vector3(0, 5.65, z), Color(1.0, 0.55, 0.2))
	Build.box(self, Vector3(0, 4.6, 0), Vector3(0.5, 0.5, 2.0 * (OPENING_HALF + PILLAR)), STONE)

	_sign = Label3D.new()
	_sign.text = "EXIT"
	_sign.font_size = 96
	_sign.pixel_size = 0.008
	_sign.modulate = Color(0.9, 0.85, 0.7)
	_sign.position = Vector3(-0.28, 4.6, 0)
	_sign.rotation_degrees.y = -90
	add_child(_sign)


func _build_door(side: float) -> Node3D:
	var hinge := Node3D.new()
	hinge.position = Vector3(0, 0, side * OPENING_HALF)
	add_child(hinge)
	var toward_center := -side
	for i in int(OPENING_HALF / BAR_STEP):
		var z := toward_center * (0.1 + i * BAR_STEP)
		Build.box(hinge, Vector3(0, DOOR_HEIGHT / 2.0, z), Vector3(0.05, DOOR_HEIGHT, 0.05), IRON)
		var tip := MeshInstance3D.new()
		tip.mesh = _tip_mesh
		tip.material_override = _iron_mat
		tip.position = Vector3(0, DOOR_HEIGHT + 0.11, z)
		hinge.add_child(tip)
	for y in [0.5, DOOR_HEIGHT - 0.4]:
		Build.box(hinge, Vector3(0, y, toward_center * OPENING_HALF / 2.0), Vector3(0.07, 0.09, OPENING_HALF), IRON)
	return hinge


func _build_lock() -> void:
	_lock = Build.box(self, Vector3(-0.1, 1.7, 0), Vector3(0.18, 0.45, 0.35), Color(1.0, 0.75, 0.25), false, 1.2)
	_lock_label = Label3D.new()
	_lock_label.text = "LOCKED\n%d pts" % StallManager.GATE_COST
	_lock_label.font_size = 56
	_lock_label.pixel_size = 0.006
	_lock_label.modulate = Color(1.0, 0.85, 0.5)
	_lock_label.position = Vector3(-0.3, 2.3, 0)
	_lock_label.rotation_degrees.y = -90
	add_child(_lock_label)


func _build_blocker() -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(0, 3.0, 0)
	_blocker = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 6.0, OPENING_HALF * 2.0)
	_blocker.shape = shape
	body.add_child(_blocker)
	add_child(body)


func _build_areas() -> void:
	var talk := Area3D.new()
	talk.collision_layer = 2
	talk.collision_mask = 0
	talk.monitoring = false
	talk.position = Vector3(-0.6, 1.5, 0)
	var talk_shape := CollisionShape3D.new()
	var talk_box := BoxShape3D.new()
	talk_box.size = Vector3(1.2, 3.0, OPENING_HALF * 2.0)
	talk_shape.shape = talk_box
	talk.add_child(talk_shape)
	add_child(talk)

	var exit := Area3D.new()
	exit.collision_layer = 0
	exit.collision_mask = 1
	exit.position = Vector3(3.0, 1.0, 0)
	var exit_shape := CollisionShape3D.new()
	var exit_box := BoxShape3D.new()
	exit_box.size = Vector3(3.0, 2.0, OPENING_HALF * 2.0)
	exit_shape.shape = exit_box
	exit.add_child(exit_shape)
	exit.body_entered.connect(_on_exit_body_entered)
	add_child(exit)


# A short walled path outside the gate so the player can step out without falling off the platform.
func _build_exit_path() -> void:
	Build.box(self, Vector3(2.25, -0.25, 0), Vector3(5.5, 0.5, OPENING_HALF * 2.5), Color(0.18, 0.16, 0.14), true)
	for side in [-1.0, 1.0]:
		Build.invisible_wall(self, Vector3(2.5, 3.0, side * 3.0), Vector3(6.0, 6.0, 1.0))
	Build.invisible_wall(self, Vector3(5.5, 3.0, 0), Vector3(1.0, 6.0, 7.0))


func _on_exit_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		StallManager.escape()


func _on_gate_opened(animate: bool) -> void:
	_blocker.set_deferred("disabled", true)
	_lock.hide()
	_lock_label.hide()
	_sign.modulate = OPEN_COLOR
	_light.light_color = OPEN_COLOR
	_exit_light.visible = true
	for i in _doors.size():
		var angle := 90.0 if i == 0 else -90.0
		if animate:
			var tween := create_tween()
			tween.tween_property(_doors[i], "rotation_degrees:y", angle, 1.6).set_trans(Tween.TRANS_SINE)
		else:
			_doors[i].rotation_degrees.y = angle
