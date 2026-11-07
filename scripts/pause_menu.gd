extends CanvasLayer

const UIKit = preload("res://scripts/ui_kit.gd")
const SettingsMenu = preload("res://scripts/settings_menu.gd")
const MENU_SCENE := "res://scenes/menu.tscn"

var game_manager: Node
var minigames: Node

var _panel: Control
var _resume: Button


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = Control.new()
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := UIKit.screen(_panel, Color(0, 0, 0, 0.65))
	box.add_child(UIKit.title("Paused", 64))
	box.add_child(UIKit.divider())
	_resume = UIKit.button("Resume", close, true)
	box.add_child(_resume)
	box.add_child(UIKit.button("Settings", _open_settings))
	box.add_child(UIKit.button("Save and back to menu", _back_to_menu))
	box.add_child(UIKit.divider())
	box.add_child(UIKit.controls_card())
	_panel.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _panel.visible:
			close()
		else:
			open()


func open() -> void:
	if _panel.visible or game_manager.sequence_running or PointManager.is_game_over:
		return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel.show()
	_resume.grab_focus()


func _open_settings() -> void:
	var s := SettingsMenu.new()
	s.closed.connect(func(): _resume.grab_focus())
	add_child(s)


func close() -> void:
	_panel.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _back_to_menu() -> void:
	# Leaving mid-round counts as a forfeit, so quitting can't dodge a penalty.
	minigames.forfeit()
	SaveManager.save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
