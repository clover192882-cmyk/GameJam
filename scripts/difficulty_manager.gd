extends Node

signal difficulty_unlocked(stall_id: String, level: int)
signal selection_changed(stall_id: String, level: int)

const NAMES := ["Easy", "Medium", "Hard"]
# Cost to unlock each level; index 0 is free.
const UNLOCK_COSTS := [0, 40, 90]
# Each repeat win at the same stall + difficulty pays less, down to a floor.
const REPEAT_DECAY := 0.25
const REPEAT_FLOOR := 0.25

var _max_level := {"dart": 0, "goldfish": 0, "cork": 0}
var _selected := {"dart": 0, "goldfish": 0, "cork": 0}
var _wins := {}


func reset() -> void:
	for id in _max_level:
		_max_level[id] = 0
		_selected[id] = 0
	_wins.clear()


func to_dict() -> Dictionary:
	return {"max_level": _max_level.duplicate(), "selected": _selected.duplicate(), "wins": _wins.duplicate()}


func from_dict(data: Dictionary) -> void:
	reset()
	var top := NAMES.size() - 1
	var saved_max = data.get("max_level")
	var saved_selected = data.get("selected")
	var saved_wins = data.get("wins")
	for id in _max_level:
		if saved_max is Dictionary and saved_max.get(id) is float:
			_max_level[id] = clampi(int(saved_max[id]), 0, top)
		if saved_selected is Dictionary and saved_selected.get(id) is float:
			_selected[id] = clampi(int(saved_selected[id]), 0, _max_level[id])
	if saved_wins is Dictionary:
		for key in saved_wins:
			if key is String and saved_wins[key] is float:
				_wins[key] = maxi(int(saved_wins[key]), 0)


func max_level(id: String) -> int:
	return _max_level.get(id, 0)


func selected(id: String) -> int:
	return _selected.get(id, 0)


func level_name(level: int) -> String:
	return NAMES[clampi(level, 0, NAMES.size() - 1)]


func next_unlock_cost(id: String) -> int:
	var next: int = max_level(id) + 1
	return UNLOCK_COSTS[next] if next < UNLOCK_COSTS.size() else -1


func try_unlock_next(id: String) -> bool:
	var cost := next_unlock_cost(id)
	if cost < 0 or not StallManager.is_unlocked(id):
		return false
	if not PointManager.spend(cost):
		return false
	_max_level[id] += 1
	_selected[id] = _max_level[id]
	difficulty_unlocked.emit(id, _max_level[id])
	selection_changed.emit(id, _selected[id])
	return true


func cycle_selected(id: String) -> void:
	_selected[id] = (selected(id) + 1) % (max_level(id) + 1)
	selection_changed.emit(id, _selected[id])


func reward_multiplier(id: String, level: int) -> float:
	var wins: int = _wins.get("%s_%d" % [id, level], 0)
	return maxf(1.0 - wins * REPEAT_DECAY, REPEAT_FLOOR)


func record_win(id: String, level: int) -> void:
	var key := "%s_%d" % [id, level]
	_wins[key] = _wins.get(key, 0) + 1
