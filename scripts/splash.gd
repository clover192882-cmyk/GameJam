extends Control

const UIKit = preload("res://scripts/ui_kit.gd")
const MENU_SCENE := "res://scenes/menu.tscn"
const FADE_IN := 1.0
const HOLD := 1.8
const FADE_OUT := 0.8

var _content: Control
var _leaving := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var box := UIKit.screen(self, Color(0.02, 0.01, 0.04), false)
	_content = box.get_parent()
	box.add_child(UIKit.label("~  A GAME JAM STORY  ~", 18, Color(UIKit.GOLD, 0.7)))
	box.add_child(UIKit.title("Hollow Matsuri", 96))
	box.add_child(UIKit.divider())
	box.add_child(UIKit.label("The lanterns never go out.", 26, Color(0.85, 0.78, 0.68)))
	var prompt := UIKit.label("Press any key", 16, Color(UIKit.CREAM, 0.5))
	box.add_child(prompt)

	_content.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_content, "modulate:a", 1.0, FADE_IN)
	tw.tween_interval(HOLD)
	tw.tween_callback(_leave)

	var pulse := create_tween().set_loops()
	pulse.tween_property(prompt, "modulate:a", 0.3, 0.8)
	pulse.tween_property(prompt, "modulate:a", 1.0, 0.8)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			or event is InputEventMouseButton and event.pressed:
		_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	var tw := create_tween()
	tw.tween_property(_content, "modulate:a", 0.0, FADE_OUT)
	tw.tween_callback(func(): get_tree().change_scene_to_file(MENU_SCENE))
