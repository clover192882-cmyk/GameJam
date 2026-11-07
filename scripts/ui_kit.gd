extends RefCounted

const GOLD := Color(1.0, 0.76, 0.38)
const CREAM := Color(0.95, 0.93, 0.88)
const RED := Color(0.62, 0.14, 0.16)
const RED_DARK := Color(0.1, 0.02, 0.04)
const INK := Color(0.04, 0.07, 0.14, 0.86)
const HUD_BG := Color(0.03, 0.05, 0.11, 0.84)
const GOOD := Color(0.55, 0.85, 0.5)
const DISPLAY_FONT := preload("res://assets/fonts/Cinzel.ttf")

static var _display: FontVariation


# Titles, headings and buttons use the display face; body text keeps the default for readability.
static func display_font() -> FontVariation:
	if _display == null:
		_display = FontVariation.new()
		_display.base_font = DISPLAY_FONT
		_display.variation_opentype = {"wght": 700}
	return _display


static func panel_style(bg := INK, border := Color(GOLD, 0.55), radius := 14, margin := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 8
	return s


static func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := panel_style(bg, border, 12, 10)
	s.shadow_size = 4
	return s


# Full-screen backdrop with a vertical gradient and a centered column inside a card.
static func screen(parent: Node, bg_color: Color, card := true) -> VBoxContainer:
	var bg := ColorRect.new()
	bg.color = bg_color
	parent.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if bg_color.a > 0.9:
		var grad := Gradient.new()
		grad.colors = PackedColorArray([Color(0.1, 0.16, 0.32), Color(0.05, 0.08, 0.18), Color(0.01, 0.02, 0.06)])
		grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill_from = Vector2(0.5, 0.0)
		tex.fill_to = Vector2(0.5, 1.0)
		var rect := TextureRect.new()
		rect.texture = tex
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(rect)
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	parent.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var holder: Control = center
	if card:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", panel_style(Color(0.04, 0.07, 0.14, 0.88), Color(GOLD, 0.6), 22, 36))
		center.add_child(panel)
		holder = panel

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	holder.add_child(box)
	return box


# Shared end-of-round lines: where the total went and whether a heart was lost.
static func summary_text(r: Dictionary) -> String:
	var text := "Total: %d  ->  %d" % [r["start"], r["final"]]
	if r["game_over"]:
		text += "
YOU LOST A HEART!
No hearts left..."
	elif r["health_lost"]:
		text += "
YOU LOST A HEART!"
	return text


static func label(text: String, font_size: int, color := CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.1))
	l.add_theme_constant_override("outline_size", maxi(font_size / 8, 3))
	return l


static func heading(text: String, font_size: int, color := GOLD) -> Label:
	var l := label(text, font_size, color)
	l.add_theme_font_override("font", display_font())
	return l


static func title(text: String, font_size: int) -> Label:
	var l := label(text, font_size, GOLD)
	l.add_theme_font_override("font", display_font())
	l.add_theme_color_override("font_outline_color", RED_DARK)
	l.add_theme_constant_override("outline_size", font_size / 5)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 4)
	return l


# A thin rule with a small diamond in the middle.
class Ornament extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(0, 14)

	func _draw() -> void:
		var c := Color(GOLD, 0.55)
		var mid := Vector2(size.x / 2.0, size.y / 2.0)
		draw_line(Vector2(0, mid.y), Vector2(mid.x - 14, mid.y), c, 2.0)
		draw_line(Vector2(mid.x + 14, mid.y), Vector2(size.x, mid.y), c, 2.0)
		draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -7), mid + Vector2(7, 0), mid + Vector2(0, 7), mid + Vector2(-7, 0)]), Color(GOLD, 0.9))


static func divider() -> Control:
	return Ornament.new()


# A small card listing the controls, shown on the menu and pause screens.
static func controls_card(compact := false) -> Control:
	var move: String = Settings.movement_name()
	var rows := [[move, "Move"], ["Double-tap " + move, "Sprint"], [Settings.key_name("jump"), "Jump"], [Settings.key_name("interact"), "Interact"],
		[Settings.key_name("toggle_view"), "Change view"], ["Hold Tab", "Show cursor"], ["Esc", "Pause"]]
	var grid := GridContainer.new()
	grid.columns = 4 if not compact else 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	for r in rows:
		var k := label(r[0], 15, GOLD)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var a := label(r[1], 15, Color(CREAM, 0.8))
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(k)
		grid.add_child(a)
	return grid


# Pill-style backdrop for HUD text that sits over the 3D scene.
static func pill(l: Label, bg := HUD_BG) -> void:
	l.add_theme_stylebox_override("normal", panel_style(bg, Color(GOLD, 0.45), 18, 12))


static func button(text: String, callback: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 54)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_font_override("font", display_font())
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", GOLD)
	var base := RED if primary else Color(0.1, 0.15, 0.27, 0.95)
	b.add_theme_stylebox_override("normal", _button_style(base, Color(GOLD, 0.5)))
	b.add_theme_stylebox_override("hover", _button_style(base.lightened(0.18), GOLD))
	b.add_theme_stylebox_override("pressed", _button_style(base.darkened(0.25), GOLD))
	b.add_theme_stylebox_override("focus", _button_style(base.lightened(0.1), Color.WHITE))
	b.pressed.connect(callback)
	b.mouse_entered.connect(func(): _pop(b, 1.04))
	b.mouse_exited.connect(func(): _pop(b, 1.0))
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	return b


static func _pop(c: Control, target: float) -> void:
	var t := c.create_tween()
	t.tween_property(c, "scale", Vector2.ONE * target, 0.1)
