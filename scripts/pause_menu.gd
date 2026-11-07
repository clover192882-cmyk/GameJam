extends CanvasLayer

const UIKit = preload("res://scripts/ui_kit.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const MENU_SCENE := "res://scenes/menu.tscn"

var game_manager: Node
var minigames: Node

var _panel: Control
var _resume: Button
var _settings: ColorRect


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = Control.new()
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := UIKit.screen(_panel, Color(0, 0, 0, 0.65))
	var t := GameSettings.t
	box.add_child(UIKit.title(t.call("Paused"), 64))
	box.add_child(UIKit.divider())
	_resume = UIKit.button(t.call("Resume"), close, true)
	box.add_child(_resume)
	_settings = SettingsPanel.new()
	box.add_child(UIKit.button(t.call("Settings"), _settings.open))
	box.add_child(UIKit.button(t.call("Save and back to menu"), _back_to_menu))
	box.add_child(UIKit.label(t.call("Esc to resume"), 16, Color(UIKit.CREAM, 0.6)))
	_panel.add_child(_settings)
	_settings.closed.connect(_resume.grab_focus)
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
