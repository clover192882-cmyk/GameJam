extends CanvasLayer

const UIKit = preload("res://scripts/ui_kit.gd")

var _game: Node
var _crosshair: Label
var _info: Label
var _hint: Label
var _result: Label
var _done := false


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_crosshair = _make_label("+", 36)
	_place(_crosshair, 0.5, 0.5, -20, -20, 20, 20)
	root.add_child(_crosshair)

	_info = _make_label("", 24)
	UIKit.pill(_info)
	_place(_info, 1.0, 0.0, -576, 16, -16, 60)
	root.add_child(_info)

	_hint = _make_label("Click to shoot   |   R or right click to reload   |   E to give up", 20)
	_place(_hint, 0.5, 1.0, -460, -150, 460, -112)
	UIKit.pill(_hint)
	root.add_child(_hint)

	_result = _make_label("", 40)
	_place(_result, 0.5, 0.5, -320, -90, 320, 90)
	_result.add_theme_stylebox_override("normal", UIKit.panel_style(UIKit.INK, UIKit.TRIM, 12, 24))
	_result.hide()
	root.add_child(_result)


func bind(game: Node) -> void:
	_game = game
	game.round_finished.connect(_on_finished)


func _process(_delta: float) -> void:
	if _done or _game == null:
		return
	var h: Dictionary = _game.hud()
	var ammo_text := "RELOADING..." if h["reloading"] else "Corks %d / %d" % [h["ammo"], h["max_ammo"]]
	_info.text = "Time %d     %s     Score %+d" % [ceili(h["time_left"]), ammo_text, h["net"]]


func _on_finished(won: bool, net: int, hits: int) -> void:
	_done = true
	_crosshair.hide()
	_hint.hide()
	_info.hide()
	_result.text = "%s\nDucks hit: %d\nPoints: %+d" % ["Nice shooting!" if won else "Out of luck...", hits, net]
	_result.show()


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UIKit.CREAM)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.1))
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
