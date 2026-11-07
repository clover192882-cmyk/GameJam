extends Node

const DartGame = preload("res://scripts/dart_game.gd")
const DartUI = preload("res://scripts/dart_ui.gd")
const GoldfishGame = preload("res://scripts/goldfish_game.gd")
const GoldfishUI = preload("res://scripts/goldfish_ui.gd")
const CorkGame = preload("res://scripts/cork_game.gd")
const CorkUI = preload("res://scripts/cork_ui.gd")
const STAND_OFFSET := Vector3(0, 0.05, 2.3)

signal round_started
signal round_ended

var player: CharacterBody3D
var audio: Node
var _active := false
var _current_id := ""
var _current_level := 0
var _game: Node
var _ui: Node


func start_for_stall(stall: Node3D) -> void:
	if _active or PointManager.is_game_over:
		return
	if not stall.unlocked:
		StallManager.try_unlock(stall.stall_id)
		return
	match stall.stall_id:
		"dart":
			_begin(stall, DartGame.new(), DartUI.new(), deg_to_rad(5), true)
			_game.round_finished.connect(func(net, _pops, _misses): _apply_result(net))
		"goldfish":
			_begin(stall, GoldfishGame.new(), GoldfishUI.new(), deg_to_rad(-30), true)
			_game.round_finished.connect(func(_won, net, _catches): _apply_result(net))
		"cork":
			_begin(stall, CorkGame.new(), CorkUI.new(), 0.0, true)
			_game.round_finished.connect(func(_won, net, _hits): _apply_result(net))


func forfeit() -> void:
	if _active and _game:
		_game.forfeit()


func _begin(stall: Node3D, game: Node, ui: Node, pitch: float, allow_look := false) -> void:
	_active = true
	PointManager.begin_round()
	round_started.emit()
	_current_id = stall.stall_id
	player.interaction.enabled = false
	var offset: Vector3 = game.get("stand_offset") if game.get("stand_offset") != null else STAND_OFFSET
	var view_pitch: float = game.get("view_pitch") if game.get("view_pitch") != null else pitch
	player.lock_view(stall.global_position + offset, 0.0, view_pitch, allow_look)

	_game = game
	_ui = ui
	add_child(_game)
	add_child(_ui)
	_ui.bind(_game)
	_game.closed.connect(_on_closed)
	_current_level = DifficultyManager.selected(stall.stall_id)
	_game.reward_scale = DifficultyManager.reward_multiplier(stall.stall_id, _current_level)
	_hook_audio()
	_game.start(stall, _current_level)


func _hook_audio() -> void:
	if not audio:
		return
	if _game.has_signal("dart_resolved"):
		_game.dart_resolved.connect(func(hit): audio.play("balloon_pop" if hit else "dart_hit"))
		_game.dart_thrown.connect(func(): audio.play("dart_throw"))
	elif _game.has_signal("shot_fired"):
		_game.reload_started.connect(func(): audio.play("reload"))
		_game.shot_fired.connect(func(hit):
			audio.play("gunshot")
			if hit:
				get_tree().create_timer(0.12).timeout.connect(func(): audio.play("quack")))
	elif _game.has_signal("sfx"):
		_game.sfx.connect(audio.play)
	else:
		audio.play("splash")


func _apply_result(net: int) -> void:
	if net > 0:
		PointManager.add_points(net)
		DifficultyManager.record_win(_current_id, _current_level)
		StallManager.mark_completed(_current_id)
	elif net < 0:
		PointManager.deduct_points(-net)
	var summary := PointManager.finish_round()
	if _ui and _ui.has_method("add_summary"):
		_ui.add_summary(summary)


func _on_closed() -> void:
	_game.queue_free()
	_ui.queue_free()
	_active = false
	round_ended.emit()
	player.unlock_view()
	if not PointManager.is_game_over:
		player.interaction.enabled = true
