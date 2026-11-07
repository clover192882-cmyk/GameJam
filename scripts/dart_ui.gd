extends CanvasLayer

const UIKit = preload("res://scripts/ui_kit.gd")

const BAR_HEIGHT := 320.0
const BAR_WIDTH := 34.0

var _bar: ColorRect
var _fill: ColorRect
var _marker: ColorRect
var _power_title: Label
var _hint: Label
var _info: Label
var _result: Label
var _crosshair: Label
var _total_rounds := 5
var _flash: Label


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_bar = ColorRect.new()
	_bar.color = Color(0.04, 0.07, 0.14, 0.8)
	_place(_bar, 1.0, 0.5, -90, -BAR_HEIGHT / 2, -90 + BAR_WIDTH, BAR_HEIGHT / 2)
	root.add_child(_bar)

	_fill = ColorRect.new()
	_fill.color = Color(1.0, 0.76, 0.38, 0.95)
	_fill.size = Vector2(BAR_WIDTH, 0)
	_fill.position.y = BAR_HEIGHT
	_bar.add_child(_fill)

	_marker = ColorRect.new()
	_marker.color = Color(1, 1, 1)
	_marker.size = Vector2(BAR_WIDTH + 12, 4)
	_marker.position = Vector2(-6, BAR_HEIGHT - 2)
	_bar.add_child(_marker)

	_power_title = _make_label("POWER", 20)
	_place(_power_title, 1.0, 0.5, -130, -BAR_HEIGHT / 2 - 40, -50, -BAR_HEIGHT / 2 - 8)
	root.add_child(_power_title)

	_hint = _make_label("Aim with the mouse  -  hold LEFT CLICK to build power, release to throw   |   E to give up", 22)
	_place(_hint, 0.5, 1.0, -480, -78, 480, -30)
	UIKit.pill(_hint)
	root.add_child(_hint)

	_crosshair = _make_label("+", 36)
	_place(_crosshair, 0.5, 0.5, -20, -20, 20, 20)
	root.add_child(_crosshair)

	_info = _make_label("", 28)
	_place(_info, 1.0, 0.0, -616, 16, -16, 64)
	UIKit.pill(_info)
	root.add_child(_info)

	_flash = _make_label("", 72)
	_place(_flash, 0.5, 0.5, -300, -200, 300, -100)
	_flash.pivot_offset = Vector2(300, 50)
	_flash.modulate.a = 0.0
	root.add_child(_flash)

	_result = _make_label("", 40)
	_place(_result, 0.5, 0.5, -300, -110, 300, 110)
	_result.add_theme_stylebox_override("normal", UIKit.panel_style(UIKit.INK, UIKit.TRIM, 12, 24))
	_result.hide()
	root.add_child(_result)


func bind(game: Node) -> void:
	_total_rounds = game.ROUNDS_PER_SESSION
	game.power_changed.connect(_on_power)
	game.stats_changed.connect(_on_stats)
	game.round_finished.connect(_on_finished)
	game.dart_resolved.connect(_on_resolved)


func _on_resolved(hit: bool) -> void:
	_flash.text = "POP!" if hit else "MISS"
	_flash.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3) if hit else Color(0.6, 0.6, 0.75))
	_flash.modulate.a = 1.0
	_flash.scale = Vector2(0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(_flash, "scale", Vector2(1.2, 1.2), 0.15)
	tween.tween_property(_flash, "scale", Vector2.ONE, 0.1)
	tween.tween_interval(0.35)
	tween.tween_property(_flash, "modulate:a", 0.0, 0.25)


func _on_power(power: float) -> void:
	_fill.color = Color(0.45, 0.85, 0.5).lerp(Color(1.0, 0.3, 0.2), power)
	_fill.size.y = power * BAR_HEIGHT
	_fill.position.y = BAR_HEIGHT - _fill.size.y
	_marker.position.y = _fill.position.y - _marker.size.y / 2


func _on_stats(darts_left: int, pops: int, net: int) -> void:
	var round_no := mini(_total_rounds - darts_left + (1 if darts_left > 0 else 0), _total_rounds)
	_info.text = "Round %d / %d     Popped: %d     Score: %+d" % [round_no, _total_rounds, pops, net]


func _on_finished(net: int, pops: int, misses: int) -> void:
	_bar.hide()
	_power_title.hide()
	_hint.hide()
	_crosshair.hide()
	_result.text = "SESSION COMPLETE\n\nPopped: %d     Missed: %d\nPoints: %+d" % [pops, misses, net]
	_result.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6) if net > 0 else (Color(1.0, 0.4, 0.6) if net < 0 else UIKit.CREAM))
	_result.show()


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	return label


func _place(c: Control, ax: float, ay: float, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b


func add_summary(r: Dictionary) -> void:
	_result.text += "
" + UIKit.summary_text(r)
	if r["health_lost"]:
		_result.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
