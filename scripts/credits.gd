extends CanvasLayer

const UIKit = preload("res://scripts/ui_kit.gd")
const SCROLL_TIME := 26.0
const SECTIONS := [
	["HOLLOW MATSURI", ["Win their games. Earn points. Open the gate and run."]],
	["GAME DESIGN AND CODE", ["Built with Godot Engine 4"]],
	["MODELS", [
		"Darts by Jarlan Perez (poly.pizza) - CC BY 3.0",
		"Goldfish and fish models from the ye_fish_duck package",
		"(license to be confirmed)",
	]],
	["FONT", ["Cinzel by Natanael Gama - SIL Open Font License"]],
	["AUDIO", ["CC0 sound effects and music from OpenGameArt", "Eerie drone and chimes synthesized in Godot"]],
	["THANK YOU FOR PLAYING", []],
]

signal finished

var _box: VBoxContainer
var _tween: Tween
var _done := false


func _ready() -> void:
	layer = 30
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.03, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	_box.custom_minimum_size = Vector2(900, 0)
	add_child(_box)
	for s in SECTIONS:
		_box.add_child(UIKit.label(s[0], 38, UIKit.GOLD))
		for line in s[1]:
			_box.add_child(UIKit.label(line, 24))
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 50)
		_box.add_child(gap)
	for c in _box.get_children():
		if c is Label:
			c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := UIKit.label("Esc or click to skip", 16, Color(UIKit.CREAM, 0.5))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-70, -40)
	add_child(hint)
	await get_tree().process_frame
	var vs := get_viewport().get_visible_rect().size
	_box.position = Vector2((vs.x - 900.0) / 2.0, vs.y)
	_tween = create_tween()
	_tween.tween_property(_box, "position:y", -_box.size.y, SCROLL_TIME)
	_tween.tween_callback(_end)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed):
		_end()


func _end() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()
