extends RefCounted

const GOLD := Color(0.85, 0.75, 0.45)
const CREAM := Color(0.9, 0.88, 0.8)
const BLOOD := Color(0.75, 0.08, 0.08)
const RED := Color(0.35, 0.05, 0.06)
const RED_DARK := Color(0.2, 0.05, 0.06)
const MUTED := Color(0.65, 0.65, 0.7)
const TRIM := Color(0.4, 0.3, 0.15)
const INK := Color(0.06, 0.045, 0.055, 0.96)
const BG_TOP := Color(0.02, 0.02, 0.06)
const BG_BOTTOM := Color(0.09, 0.03, 0.05)


static func panel_style(bg := INK, border := TRIM, radius := 12, margin := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.shadow_color = Color(0, 0, 0, 0.55)
	s.shadow_size = 10
	return s


static func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := panel_style(bg, border, 6, 8)
	s.content_margin_left = 16
	s.content_margin_right = 16
	return s


static func circle_texture(diameter: int, color: Color) -> ImageTexture:
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var c := (diameter - 1) / 2.0
	for y in diameter:
		for x in diameter:
			var d := Vector2(x, y).distance_to(Vector2(c, c))
			img.set_pixel(x, y, Color(color.r, color.g, color.b, clampf(c + 0.5 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


static func make_theme() -> Theme:
	var t := Theme.new()
	t.set_font_size("font_size", "Label", 24)
	t.set_color("font_color", "Label", CREAM)
	t.set_stylebox("slider", "HSlider", panel_style(Color(0.14, 0.11, 0.12), TRIM, 4, 5))
	t.set_stylebox("grabber_area", "HSlider", panel_style(BLOOD, BLOOD, 4, 5))
	t.set_stylebox("grabber_area_highlight", "HSlider", panel_style(Color(0.9, 0.15, 0.12), GOLD, 4, 5))
	t.set_icon("grabber", "HSlider", circle_texture(26, GOLD))
	t.set_icon("grabber_highlight", "HSlider", circle_texture(26, Color.WHITE))
	t.set_icon("grabber_disabled", "HSlider", circle_texture(26, MUTED))
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_stylebox("normal", "Button", _button_style(Color(0.08, 0.06, 0.07, 0.92), TRIM))
	t.set_stylebox("hover", "Button", _button_style(RED, GOLD))
	t.set_stylebox("pressed", "Button", _button_style(Color(0.5, 0.06, 0.07), Color.WHITE))
	return t


# Full-screen backdrop with a vertical gradient and a centered column, optionally inside a card.
static func screen(parent: Node, bg_color: Color, card := true) -> VBoxContainer:
	var bg := ColorRect.new()
	bg.color = bg_color
	parent.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if bg_color.a > 0.9:
		var grad := Gradient.new()
		grad.colors = PackedColorArray([BG_TOP, BG_BOTTOM])
		grad.offsets = PackedFloat32Array([0.0, 1.0])
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
		panel.add_theme_stylebox_override("panel", panel_style(INK, TRIM, 12, 36))
		center.add_child(panel)
		holder = panel

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	holder.add_child(box)
	return box


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
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.03))
	l.add_theme_constant_override("outline_size", maxi(font_size / 8, 3))
	return l


static func title(text: String, font_size: int) -> Label:
	var l := label(text, font_size, GOLD)
	l.add_theme_color_override("font_outline_color", Color(0.3, 0.0, 0.0))
	l.add_theme_constant_override("outline_size", font_size / 5)
	return l


# A thin gold rule with a diamond in the middle, for under titles.
static func divider(width := 360.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, 14)
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.draw.connect(func():
		var mid := c.size.y / 2.0
		var cx := c.size.x / 2.0
		c.draw_line(Vector2(0, mid), Vector2(cx - 14.0, mid), TRIM, 2.0)
		c.draw_line(Vector2(cx + 14.0, mid), Vector2(c.size.x, mid), TRIM, 2.0)
		c.draw_colored_polygon(PackedVector2Array([
			Vector2(cx, mid - 6), Vector2(cx + 6, mid), Vector2(cx, mid + 6), Vector2(cx - 6, mid)]), GOLD))
	return c


# Panel-style backdrop for HUD text that sits over the 3D scene.
static func pill(l: Label, bg := Color(0.06, 0.045, 0.055, 0.78)) -> void:
	l.add_theme_stylebox_override("normal", panel_style(bg, Color(TRIM, 0.9), 8, 10))


static func button(text: String, callback: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 62)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var base := Color(0.2, 0.05, 0.06, 0.96) if primary else Color(0.08, 0.06, 0.07, 0.92)
	b.add_theme_stylebox_override("normal", _button_style(base, GOLD if primary else TRIM))
	b.add_theme_stylebox_override("hover", _button_style(RED.lightened(0.05), GOLD))
	b.add_theme_stylebox_override("pressed", _button_style(Color(0.5, 0.06, 0.07), Color.WHITE))
	b.add_theme_stylebox_override("focus", _button_style(RED_DARK, GOLD))
	b.pressed.connect(callback)
	add_hover_pop(b)
	return b


# Buttons grow slightly on hover and focus.
static func add_hover_pop(b: Control) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	var pop := func(to: float):
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(to, to), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	b.mouse_entered.connect(pop.bind(1.05))
	b.mouse_exited.connect(pop.bind(1.0))
	b.focus_entered.connect(pop.bind(1.05))
	b.focus_exited.connect(pop.bind(1.0))
