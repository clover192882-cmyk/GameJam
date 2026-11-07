extends CanvasLayer

const UIKit = preload("res://scripts/ui_kit.gd")
const POI_R := 42.0

var _game: Node
var _canvas: Control
var _hint: Label
var _info: Label
var _result: Label
var _done := false


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_overlay)
	root.add_child(_canvas)

	_info = _make_label("", 24)
	UIKit.pill(_info)
	_place(_info, 0.5, 1.0, -400, -204, 400, -164)
	root.add_child(_info)

	_hint = _make_label("Aim at a fish and click to scoop it   |   SPACE in the green zone   |   E to give up", 20)
	_place(_hint, 0.5, 1.0, -460, -150, 460, -112)
	UIKit.pill(_hint)
	root.add_child(_hint)

	_result = _make_label("", 40)
	_place(_result, 0.5, 0.5, -320, -90, 320, 90)
	_result.add_theme_stylebox_override("normal", UIKit.panel_style(Color(0.04, 0.07, 0.14, 0.92), UIKit.GOLD, 22, 24))
	_result.hide()
	root.add_child(_result)


func bind(game: Node) -> void:
	_game = game
	game.round_finished.connect(_on_finished)


func _process(_delta: float) -> void:
	if not _done:
		_canvas.queue_redraw()


func _on_finished(won: bool, net: int, catches: int) -> void:
	_done = true
	_canvas.queue_redraw()
	_canvas.hide()
	_hint.hide()
	_info.hide()
	_result.text = "%s\nFish caught: %d\nPoints: %+d" % ["You scooped it!" if won else "The paper tore...", catches, net]
	_result.show()


func _text(pos: Vector2, s: String, size: int, color: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var font := ThemeDB.fallback_font
	_canvas.draw_string_outline(font, pos, s, align, width, size, 6, Color(0.02, 0.04, 0.1))
	_canvas.draw_string(font, pos, s, align, width, size, color)


func _draw_overlay() -> void:
	if _game == null:
		return
	var h: Dictionary = _game.hud()
	var vs := _canvas.size
	_draw_poi(h)
	_info.text = "Time %d     Scoops %d / %d     Paper %d%%     Score %+d" % [ceili(h["time_left"]), h["nets_left"], h["max_nets"], int(h["integrity"]), h["net"]]
	if h["state"] == 1:
		_draw_qte(h, vs)
	if h["msg_left"] > 0.0:
		var col: Color = h["msg_color"]
		col.a = minf(h["msg_left"] * 2.0, 1.0)
		_text(Vector2(0, vs.y * 0.2), h["msg"], 30, col, vs.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_poi(h: Dictionary) -> void:
	var p: Vector2 = h["poi"]
	var wear := 1.0 - float(h["integrity"]) / 100.0
	var r := POI_R * (1.0 - float(h["dip"])) if h["state"] == 0 else POI_R * 0.85
	var ring := Color(0.95, 0.92, 0.8).lerp(Color(0.5, 0.35, 0.2), wear)
	_canvas.draw_circle(p, r, Color(ring.r, ring.g, ring.b, 0.2))
	_canvas.draw_arc(p, r, 0.0, TAU, 48, ring, 4.0)
	for i in int((100.0 - float(h["integrity"])) / float(h["fail_cost"])):
		var a := 1.1 + i * 1.7
		_canvas.draw_line(p + Vector2(cos(a), sin(a)) * r * 0.2, p + Vector2(cos(a + 0.3), sin(a + 0.3)) * r, Color(0.2, 0.12, 0.05), 2.0)


func _draw_qte(h: Dictionary, vs: Vector2) -> void:
	var bar_w: float = h["bar_w"]
	var bar := Rect2(vs.x * 0.5 - bar_w / 2.0, vs.y - 90.0, bar_w, 28)
	var zw: float = h["zone_w"]
	var zc: float = h["zone_c"]
	_canvas.draw_rect(bar, Color(0.1, 0.1, 0.12))
	_canvas.draw_rect(Rect2(bar.position.x + (zc - zw / 2.0) * bar.size.x, bar.position.y, zw * bar.size.x, bar.size.y), Color(0.2, 0.8, 0.3))
	_canvas.draw_rect(Rect2(bar.position.x + float(h["ind"]) * bar.size.x - 3.0, bar.position.y - 6.0, 6, bar.size.y + 12.0), Color.WHITE)
	_canvas.draw_rect(bar, Color(1, 1, 1, 0.8), false, 2.0)
	_text(Vector2(bar.position.x, bar.position.y - 16), "Stage %d / %d  -  press SPACE in the green" % [h["stage"], h["stages"]], 22, UIKit.CREAM)
	_canvas.draw_rect(Rect2(bar.position.x, bar.end.y + 8.0, bar.size.x * float(h["qte_left"]) / float(h["qte_time"]), 4), Color(1, 0.8, 0.3))


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
