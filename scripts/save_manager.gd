extends Node

const SAVE_PATH := "user://savegame.json"
const VERSION := 1


func _ready() -> void:
	# A finished run (won or lost) can't be continued, so its save is removed.
	PointManager.game_over.connect(delete_save)
	StallManager.escaped.connect(delete_save)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func peek_points() -> int:
	var data := _read()
	return int(data.get("points", 0)) if not data.is_empty() else 0


func save_game() -> void:
	if PointManager.is_game_over or StallManager.has_escaped:
		return
	var data := {
		"version": VERSION,
		"points": PointManager.points,
		"health": PointManager.health,
		"stalls": StallManager.to_dict(),
		"difficulty": DifficultyManager.to_dict(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save file: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data))


# Replaces the in-memory state with the saved one. Returns false (leaving a fresh game) if the file is unusable.
func load_game() -> bool:
	new_game(false)
	var data := _read()
	if data.is_empty() or not data.get("points") is float:
		return false
	PointManager.load_points(int(data.points), int(data.get("health", PointManager.MAX_HEALTH)))
	if data.get("stalls") is Dictionary:
		StallManager.from_dict(data.stalls)
	if data.get("difficulty") is Dictionary:
		DifficultyManager.from_dict(data.difficulty)
	return true


# Starting a new game wipes the old save so nothing carries over.
func new_game(wipe_save := true) -> void:
	if wipe_save:
		delete_save()
	PointManager.reset()
	StallManager.reset()
	DifficultyManager.reset()


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


func _read() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return {}
	return json.data
