extends Node

signal stall_unlocked(id: String)
signal stall_completed(id: String)
signal gate_opened
signal escaped

const UNLOCK_COSTS := {"dart": 0, "goldfish": 150, "cork": 300}
const GATE_COST := 1000

var gate_open := false
var has_escaped := false
var layout_seed := randi()

var _unlocked := {"dart": true, "goldfish": false, "cork": false}
var _completed := {"dart": false, "goldfish": false, "cork": false}


func reset() -> void:
	for id in _unlocked:
		_unlocked[id] = (id == "dart")
		_completed[id] = false
	gate_open = false
	has_escaped = false
	layout_seed = randi()


func to_dict() -> Dictionary:
	return {"unlocked": _unlocked.duplicate(), "completed": _completed.duplicate(), "gate_open": gate_open, "layout_seed": layout_seed}


func from_dict(data: Dictionary) -> void:
	reset()
	var unlocked = data.get("unlocked")
	var completed = data.get("completed")
	for id in _unlocked:
		if unlocked is Dictionary and unlocked.get(id) == true:
			_unlocked[id] = true
		if completed is Dictionary and completed.get(id) == true:
			_completed[id] = true
	gate_open = data.get("gate_open") == true
	var saved_seed = data.get("layout_seed")
	if saved_seed is float or saved_seed is int:
		layout_seed = int(saved_seed)


func is_unlocked(id: String) -> bool:
	return _unlocked.get(id, false)


func is_completed(id: String) -> bool:
	return _completed.get(id, false)


func cost_of(id: String) -> int:
	return UNLOCK_COSTS.get(id, 0)


func try_unlock(id: String) -> bool:
	if is_unlocked(id) or not UNLOCK_COSTS.has(id):
		return false
	if not PointManager.spend(UNLOCK_COSTS[id]):
		return false
	_unlocked[id] = true
	stall_unlocked.emit(id)
	return true


func mark_completed(id: String) -> void:
	if not _unlocked.get(id, false) or _completed.get(id, true):
		return
	_completed[id] = true
	stall_completed.emit(id)


func try_open_gate() -> bool:
	if gate_open or not PointManager.spend(GATE_COST):
		return false
	gate_open = true
	gate_opened.emit()
	return true


# Called when the player walks out through the open gate; this is the win condition.
func escape() -> void:
	if not gate_open or has_escaped or PointManager.is_game_over:
		return
	has_escaped = true
	escaped.emit()
