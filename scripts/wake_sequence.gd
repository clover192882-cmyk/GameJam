extends Node

static var pending := false

var player: CharacterBody3D
var hud: CanvasLayer

var _black: ColorRect
var _caption: Label


func begin() -> void:
	pending = false
	player.movement_enabled = false
	player.look_enabled = false
	player.interaction.enabled = false
	hud.hide()

	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_black)
	_caption = Label.new()
	_caption.anchor_left = 0.0
	_caption.anchor_right = 1.0
	_caption.anchor_top = 1.0
	_caption.anchor_bottom = 1.0
	_caption.offset_top = -150.0
	_caption.offset_bottom = -90.0
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 28)
	_caption.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.modulate.a = 0.0
	layer.add_child(_caption)

	# Lying on the ground looking up, then slowly sitting up.
	player.head.rotation.x = 1.15
	player.cam.rotation.z = 0.45
	var rise := create_tween().set_parallel(true)
	rise.tween_property(player.head, "rotation:x", 0.0, 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rise.tween_property(player.cam, "rotation:z", 0.0, 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var blink := create_tween()
	blink.tween_interval(0.6)
	blink.tween_property(_black, "color:a", 0.55, 0.9)
	blink.tween_property(_black, "color:a", 1.0, 0.5)
	blink.tween_interval(0.4)
	blink.tween_property(_black, "color:a", 0.2, 1.0)
	blink.tween_property(_black, "color:a", 0.75, 0.35)
	blink.tween_property(_black, "color:a", 0.0, 1.4)

	await _say("...Ugh...", 1.2, 2.2)
	await _say("Where... am I?", 0.4, 2.4)
	player.head.rotation.x = 0.0
	player.cam.rotation.z = 0.0
	rise.kill()
	player.movement_enabled = true
	player.look_enabled = true
	player.interaction.enabled = true
	hud.show()
	await _say("The lanterns are lit. The gates are chained shut.", 0.2, 3.2)
	await _say("You are trapped inside the carnival.", 0.2, 3.0)
	await _say("Win the games. Earn points. Find a way out.", 0.2, 3.2)
	queue_free()


func _say(text: String, wait: float, hold: float) -> void:
	await get_tree().create_timer(wait).timeout
	_caption.text = text
	var tw := create_tween()
	tw.tween_property(_caption, "modulate:a", 1.0, 0.5)
	tw.tween_interval(hold)
	tw.tween_property(_caption, "modulate:a", 0.0, 0.5)
	await tw.finished
