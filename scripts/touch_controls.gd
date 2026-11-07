extends CanvasLayer

const UIKit = preload("res://scripts/ui_kit.gd")
const STICK_RADIUS := 105.0
const KNOB_RADIUS := 44.0
const LOOK_TOP_MARGIN := 90.0

var player: CharacterBody3D

var _canvas: Control
var _stick_touch := -1
var _stick_vec := Vector2.ZERO
var _look_touch := -1
var _button_touch := {}
var _held := {}


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or "--touch" in OS.get_cmdline_user_args()


func _size() -> Vector2:
	return _canvas.get_viewport_rect().size


func _stick_center() -> Vector2:
	return Vector2(190.0, _size().y - 190.0)


func _buttons() -> Array:
	var s := _size()
	var list: Array = []
	if player == null or PointManager.is_game_over:
		return list
	if player.movement_enabled:
		list.append({"id": "jump", "text": "JUMP", "pos": Vector2(s.x - 120.0, s.y - 150.0), "r": 66.0, "action": "jump"})
		list.append({"id": "use", "text": "USE", "pos": Vector2(s.x - 280.0, s.y - 105.0), "r": 52.0, "action": "interact"})
		list.append({"id": "lvl", "text": "LEVEL", "pos": Vector2(s.x - 110.0, s.y - 300.0), "r": 40.0, "action": "difficulty_cycle"})
		list.append({"id": "view", "text": "VIEW", "pos": Vector2(s.x - 320.0, s.y - 230.0), "r": 36.0, "action": "toggle_view"})
		list.append({"id": "unl", "text": "UNLOCK", "pos": Vector2(s.x - 215.0, s.y - 265.0), "r": 40.0, "action": "difficulty_unlock"})
	else:
		list.append({"id": "act", "text": "ACT", "pos": Vector2(s.x - 120.0, s.y - 150.0), "r": 66.0, "action": "minigame_action", "click": true})
		list.append({"id": "exit", "text": "EXIT", "pos": Vector2(s.x - 280.0, s.y - 105.0), "r": 52.0, "action": "interact"})
	return list


func _button_at(pos: Vector2) -> Dictionary:
	for b in _buttons():
		if pos.distance_to(b["pos"]) <= b["r"] + 8.0:
			return b
	return {}


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	if not _canvas.visible:
		if event is InputEventScreenTouch and event.pressed:
			_canvas.visible = true
		return
	if get_tree().paused or PointManager.is_game_over:
		_release_all()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	else:
		_touch_move(event.index, event.position, event.relative)


func _touch_down(index: int, pos: Vector2) -> void:
	var b := _button_at(pos)
	if not b.is_empty():
		_button_touch[index] = b
		_set_action(b["action"], 1.0)
		if b.get("click", false):
			_mouse_click(true)
	elif _stick_touch < 0 and pos.distance_to(_stick_center()) <= STICK_RADIUS * 1.5:
		_stick_touch = index
		_update_stick(pos)
	elif _look_touch < 0 and pos.y > LOOK_TOP_MARGIN:
		_look_touch = index


func _touch_move(index: int, pos: Vector2, relative: Vector2) -> void:
	if index == _stick_touch:
		_update_stick(pos)
	elif index == _look_touch and player:
		player.look(relative * 1.3)


func _touch_up(index: int) -> void:
	if index == _stick_touch:
		_stick_touch = -1
		_stick_vec = Vector2.ZERO
		_apply_move()
	elif index == _look_touch:
		_look_touch = -1
	elif _button_touch.has(index):
		var b: Dictionary = _button_touch[index]
		_set_action(b["action"], 0.0)
		if b.get("click", false):
			_mouse_click(false)
		_button_touch.erase(index)


func _update_stick(pos: Vector2) -> void:
	_stick_vec = ((pos - _stick_center()) / STICK_RADIUS).limit_length(1.0)
	_apply_move()


func _apply_move() -> void:
	var v := _stick_vec
	if v.length() < 0.2:
		v = Vector2.ZERO
	_set_action("move_left", maxf(-v.x, 0.0))
	_set_action("move_right", maxf(v.x, 0.0))
	_set_action("move_forward", maxf(-v.y, 0.0))
	_set_action("move_back", maxf(v.y, 0.0))
	if player:
		if v.length() >= 0.92:
			player.set_sprint(true)
		elif v.length() < 0.6:
			player.set_sprint(false)


func _set_action(action: String, strength: float) -> void:
	var was: float = _held.get(action, 0.0)
	if strength <= 0.0 and was <= 0.0:
		return
	var e := InputEventAction.new()
	e.action = action
	e.pressed = strength > 0.0
	e.strength = strength
	Input.parse_input_event(e)
	_held[action] = strength


func _mouse_click(pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = _size() / 2.0
	e.global_position = e.position
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(e)


func _release_all() -> void:
	for index in _button_touch.keys():
		var b: Dictionary = _button_touch[index]
		_set_action(b["action"], 0.0)
		if b.get("click", false):
			_mouse_click(false)
	_button_touch.clear()
	_stick_touch = -1
	_stick_vec = Vector2.ZERO
	_look_touch = -1
	_apply_move()


func _process(_delta: float) -> void:
	if _canvas.visible:
		_canvas.queue_redraw()


func _draw_controls() -> void:
	var font := ThemeDB.fallback_font
	var base := Color(0.04, 0.07, 0.14, 0.5)
	var rim := Color(UIKit.GOLD, 0.7)
	var c := _stick_center()
	_canvas.draw_circle(c, STICK_RADIUS, base)
	_canvas.draw_arc(c, STICK_RADIUS, 0.0, TAU, 48, rim, 3.0, true)
	var knob := c + _stick_vec * (STICK_RADIUS - 20.0)
	_canvas.draw_circle(knob, KNOB_RADIUS, Color(UIKit.GOLD, 0.55 if _stick_touch >= 0 else 0.35))
	_canvas.draw_arc(knob, KNOB_RADIUS, 0.0, TAU, 32, rim, 3.0, true)

	var down_ids := []
	for index in _button_touch:
		down_ids.append(_button_touch[index]["id"])
	for b in _buttons():
		var fill := Color(UIKit.GOLD, 0.45) if b["id"] in down_ids else base
		_canvas.draw_circle(b["pos"], b["r"], fill)
		_canvas.draw_arc(b["pos"], b["r"], 0.0, TAU, 40, rim, 3.0, true)
		var fs := 22 if b["r"] > 50.0 else 14
		var ts := font.get_string_size(b["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		_canvas.draw_string(font, b["pos"] + Vector2(-ts.x / 2.0, fs * 0.35), b["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.CREAM)
