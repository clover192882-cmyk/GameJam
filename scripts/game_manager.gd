extends Node

const UIKit = preload("res://scripts/ui_kit.gd")
const GameOverScene = preload("res://scripts/game_over_scene.gd")
const Credits = preload("res://scripts/credits.gd")
const MENU_SCENE := "res://scenes/menu.tscn"

var player: CharacterBody3D
var hud: CanvasLayer
var sequence_running := false


func _ready() -> void:
	PointManager.game_over.connect(_on_game_over)
	StallManager.escaped.connect(_on_escaped)


func _on_game_over() -> void:
	if sequence_running:
		return
	_begin_sequence()
	# Let a minigame result summary finish before cutting away.
	await get_tree().create_timer(3.5).timeout
	var scene := GameOverScene.new()
	get_parent().add_child(scene)
	scene.begin()
	scene.play()
	await scene.finished
	scene.queue_free()
	_show_end_screen("GAME OVER", "You lost your last heart.", Color(1, 0.3, 0.3))


func _on_escaped() -> void:
	if sequence_running:
		return
	_begin_sequence()
	await get_tree().create_timer(1.0).timeout
	var credits := Credits.new()
	add_child(credits)
	await credits.finished
	_show_end_screen("YOU ESCAPED", "The gate closes behind you. You never learn who ran the carnival.", Color(1, 0.9, 0.5))


func _begin_sequence() -> void:
	sequence_running = true
	player.interaction.enabled = false
	player.movement_enabled = false
	player.look_enabled = false
	hud.hide()


func _show_end_screen(title: String, subtitle: String, color: Color) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)

	var box := UIKit.screen(layer, Color(0, 0, 0, 0.9))
	box.add_child(UIKit.label(title, 72, color))
	box.add_child(UIKit.label(subtitle, 24))
	box.add_child(UIKit.button("Play again", _restart))
	box.add_child(UIKit.button("Home menu", _go_home))


func _restart() -> void:
	SaveManager.new_game()
	get_tree().reload_current_scene()


func _go_home() -> void:
	SaveManager.new_game()
	get_tree().change_scene_to_file(MENU_SCENE)
