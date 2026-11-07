extends Node

signal prompt_changed(text: String)
signal interacted(target: Node)

var enabled := true:
	set(value):
		enabled = value
		if not value:
			_target = null
			_set_prompt("")

var _ray: RayCast3D
var _target: Node
var _prompt := ""


func _ready() -> void:
	var camera: Camera3D = get_node("../Head/Camera3D")
	_ray = RayCast3D.new()
	_ray.name = "InteractRay"
	_ray.target_position = Vector3(0, 0, -3.0)
	_ray.collision_mask = 2
	_ray.collide_with_areas = true
	_ray.collide_with_bodies = false
	camera.add_child(_ray)
	PointManager.game_over.connect(func(): enabled = false)


func _physics_process(_delta: float) -> void:
	if not enabled:
		return
	var found: Node = null
	if _ray.is_colliding():
		var hit := _ray.get_collider() as Node
		if hit and hit.get_parent().has_method("get_prompt"):
			found = hit.get_parent()
	_target = found
	_set_prompt(found.get_prompt() if found else "")


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not _target:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		interacted.emit(_target)
	elif not "stall_id" in _target or not _target.unlocked:
		return
	elif event.is_action_pressed("difficulty_cycle"):
		DifficultyManager.cycle_selected(_target.stall_id)
	elif event.is_action_pressed("difficulty_unlock"):
		DifficultyManager.try_unlock_next(_target.stall_id)


func _set_prompt(text: String) -> void:
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)
