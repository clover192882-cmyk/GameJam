extends Control

const UIKit = preload("res://scripts/ui_kit.gd")
const Credits = preload("res://scripts/credits.gd")
const GAME_SCENE := "res://scenes/main.tscn"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false

	var box := UIKit.screen(self, Color(0.03, 0.02, 0.05))
	box.add_child(UIKit.label("~  THE LANTERNS NEVER GO OUT  ~", 18, Color(UIKit.GOLD, 0.8)))
	box.add_child(UIKit.title("Hollow Matsuri", 76))
	box.add_child(UIKit.label("Win their games. Earn points. Open the gate and run.", 22, Color(0.85, 0.78, 0.68)))
	box.add_child(UIKit.divider())

	var first: Button
	if SaveManager.has_save():
		first = UIKit.button("Continue  -  %d pts" % SaveManager.peek_points(), _on_continue, true)
		box.add_child(first)
		box.add_child(UIKit.button("New game", _on_new_game))
	else:
		first = UIKit.button("New game", _on_new_game, true)
		box.add_child(first)
	box.add_child(UIKit.button("Credits", func(): add_child(Credits.new())))
	box.add_child(UIKit.button("Quit", func(): get_tree().quit()))
	first.grab_focus.call_deferred()


func _on_continue() -> void:
	SaveManager.load_game()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_new_game() -> void:
	SaveManager.new_game()
	get_tree().change_scene_to_file(GAME_SCENE)
