extends CanvasLayer

const UIKit = preload("res://scripts/ui_kit.gd")
const TABS := ["Sound and mouse", "Controls", "Graphics"]

signal closed

var _listening := ""
var _key_buttons := {}
var _refreshers: Array[Callable] = []
var _pages: Array[Control] = []
var _tab_buttons: Array[Button] = []
var _hint: Label
var _back: Button


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := UIKit.screen(root, Color(0.02, 0.03, 0.07, 0.97))
	box.add_theme_constant_override("separation", 8)
	box.add_child(UIKit.title("Settings", 44))

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 12)
	box.add_child(tabs)
	for i in TABS.size():
		var tb := UIKit.button(TABS[i], func(): _show_tab(i))
		_slim_button(tb, 210, 40, 20)
		tabs.add_child(tb)
		_tab_buttons.append(tb)
	box.add_child(UIKit.divider())

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(1000, 270)
	box.add_child(holder)
	for page in [_build_sound(), _build_keys(), _build_graphics()]:
		holder.add_child(page)
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_pages.append(page)

	box.add_child(UIKit.divider())
	_hint = UIKit.label("", 16, Color(UIKit.CREAM, 0.7))
	box.add_child(_hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	_back = UIKit.button("Back", close, true)
	var reset_all := UIKit.button("Reset all", _reset_all)
	for b in [_back, reset_all]:
		_slim_button(b, 240, 42, 22)
		row.add_child(b)
	_show_tab(0)
	_back.grab_focus.call_deferred()


func _slim_button(b: Button, w: float, h: float, font: int) -> void:
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", font)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, _slim(b, st))


static func _slim(b: Button, which: String) -> StyleBox:
	var s: StyleBoxFlat = b.get_theme_stylebox(which).duplicate()
	s.set_content_margin_all(2)
	return s


func _show_tab(index: int) -> void:
	_listening = ""
	_refresh_keys()
	for i in _pages.size():
		_pages[i].visible = i == index
		_tab_buttons[i].disabled = false
		_tab_buttons[i].modulate = Color(1, 1, 1) if i == index else Color(0.7, 0.7, 0.75)
	_set_hint()


func _page() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	return col


func _section(text: String) -> Label:
	var l := UIKit.heading(text, 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


func _gap(h: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, h)
	return g


func _build_sound() -> Control:
	var page := HBoxContainer.new()
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 70)
	var left := _page()
	left.custom_minimum_size = Vector2(430, 0)
	left.add_child(_section("Sound"))
	left.add_child(_slider("Master volume", "master", 0.0, 1.0, func(v): Settings.set_volume("master", v), _percent))
	left.add_child(_slider("Music", "music", 0.0, 1.0, func(v): Settings.set_volume("music", v), _percent))
	left.add_child(_slider("Effects", "sfx", 0.0, 1.0, func(v): Settings.set_volume("sfx", v), _percent))
	var right := _page()
	right.custom_minimum_size = Vector2(430, 0)
	right.add_child(_section("Mouse"))
	right.add_child(_slider("Look sensitivity", "sensitivity", 0.2, 3.0, Settings.set_sensitivity, func(v): return "x%.2f" % v))
	right.add_child(_toggle("Invert vertical look", "invert_y", Settings.set_invert_y))
	page.add_child(left)
	page.add_child(right)
	return page


func _build_graphics() -> Control:
	var page := HBoxContainer.new()
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 70)
	var left := _page()
	left.custom_minimum_size = Vector2(430, 0)
	left.add_child(_section("Display"))
	left.add_child(_cycler("Window mode", "display_mode", Settings.DISPLAY_MODES))
	left.add_child(_toggle("Vertical sync", "vsync", func(on): Settings.set_graphic("vsync", on)))
	left.add_child(_cycler("Frame rate limit", "fps_cap", Settings.FPS_CAPS.map(func(f): return "Unlimited" if f == 0 else "%d FPS" % f)))
	left.add_child(_slider("Field of view", "fov", 60.0, 100.0, func(v): Settings.set_graphic("fov", v), func(v): return "%d" % roundi(v)))
	left.add_child(_toggle("Head bob", "head_bob", func(on): Settings.set_graphic("head_bob", on)))
	var right := _page()
	right.custom_minimum_size = Vector2(430, 0)
	right.add_child(_section("Quality"))
	right.add_child(_slider("Render scale", "render_scale", 0.5, 1.0, func(v): Settings.set_graphic("render_scale", v), _percent))
	right.add_child(_cycler("Anti-aliasing", "msaa", Settings.MSAA_NAMES))
	right.add_child(_cycler("Shadows", "shadows", Settings.SHADOW_NAMES))
	right.add_child(_toggle("Glow", "glow", func(on): Settings.set_graphic("glow", on)))
	right.add_child(_slider("Brightness", "brightness", 0.6, 1.6, func(v): Settings.set_graphic("brightness", v), _percent))
	page.add_child(left)
	page.add_child(right)
	return page


static func _percent(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


func _toggle(title: String, prop: String, setter: Callable) -> Control:
	var cb := CheckButton.new()
	cb.text = title
	cb.focus_mode = Control.FOCUS_ALL
	cb.button_pressed = Settings.get(prop)
	cb.add_theme_font_size_override("font_size", 18)
	cb.add_theme_color_override("font_color", UIKit.CREAM)
	cb.toggled.connect(setter)
	_refreshers.append(func(): cb.set_pressed_no_signal(Settings.get(prop)))
	return cb


func _cycler(title: String, prop: String, names: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_l := UIKit.label(title, 18)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)
	var val := UIKit.label("", 18, UIKit.GOLD)
	val.custom_minimum_size = Vector2(130, 0)
	var show := func(): val.text = str(names[Settings.get(prop)])
	var step := func(d: int):
		Settings.set_graphic(prop, posmod(int(Settings.get(prop)) + d, names.size()))
		show.call()
	var prev := UIKit.button("<", func(): step.call(-1))
	var next := UIKit.button(">", func(): step.call(1))
	for b in [prev, next]:
		_slim_button(b, 40, 32, 20)
	row.add_child(prev)
	row.add_child(val)
	row.add_child(next)
	show.call()
	_refreshers.append(show)
	return row


func _slider(title: String, prop: String, lo: float, hi: float, setter: Callable, fmt: Callable) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 2)
	var top := HBoxContainer.new()
	wrap.add_child(top)
	var name_l := UIKit.label(title, 18)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	var val := UIKit.label("", 18, UIKit.GOLD)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(val)

	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.focus_mode = Control.FOCUS_ALL
	s.custom_minimum_size = Vector2(0, 24)
	s.value = Settings.get(prop)
	s.add_theme_stylebox_override("slider", _bar(Color(0.1, 0.15, 0.27), 8))
	s.add_theme_stylebox_override("grabber_area", _bar(UIKit.RED, 8))
	s.add_theme_stylebox_override("grabber_area_highlight", _bar(UIKit.RED.lightened(0.2), 8))
	s.add_theme_icon_override("grabber", _knob(false))
	s.add_theme_icon_override("grabber_highlight", _knob(true))
	val.text = fmt.call(s.value)
	s.value_changed.connect(func(v: float):
		val.text = fmt.call(v)
		setter.call(v))
	wrap.add_child(s)
	_refreshers.append(func():
		s.set_value_no_signal(Settings.get(prop))
		val.text = fmt.call(s.value))
	return wrap


static func _bar(c: Color, h: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(h / 2)
	sb.content_margin_top = h / 2.0
	sb.content_margin_bottom = h / 2.0
	sb.border_color = Color(UIKit.GOLD, 0.4)
	sb.set_border_width_all(1)
	return sb


static func _knob(lit: bool) -> Texture2D:
	var img := Image.create(26, 26, false, Image.FORMAT_RGBA8)
	var c := Vector2(12.5, 12.5)
	for x in 26:
		for y in 26:
			var d := Vector2(x, y).distance_to(c)
			if d <= 12.0:
				img.set_pixel(x, y, Color.WHITE if lit else UIKit.GOLD if d < 9.0 else Color(0.5, 0.35, 0.1))
	return ImageTexture.create_from_image(img)


func _build_keys() -> Control:
	var page := HBoxContainer.new()
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	var col := _page()
	col.custom_minimum_size = Vector2(900, 0)
	col.add_theme_constant_override("separation", 10)
	col.add_child(_section("Controls  -  click a key to change it"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	for b in Settings.BINDINGS:
		var name_l := UIKit.label(b[1], 18)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_l)
		var kb := UIKit.button("", func(): _listen(b[0]))
		_slim_button(kb, 170, 30, 16)
		grid.add_child(kb)
		_key_buttons[b[0]] = kb
	var reset := UIKit.button("Reset keys", func():
		Settings.reset_keys()
		_refresh_keys())
	_slim_button(reset, 0, 36, 18)
	col.add_child(reset)
	page.add_child(col)
	_refresh_keys()
	return page


func _refresh_keys() -> void:
	for action in _key_buttons:
		_key_buttons[action].text = "press a key..." if action == _listening else Settings.key_name(action)


func _set_hint() -> void:
	if _listening != "":
		_hint.text = "Press the new key, or Esc to cancel.  (Esc and Tab are reserved.)"
	else:
		_hint.text = "Changes are saved automatically.  Double-tap a movement key to sprint."


func _listen(action: String) -> void:
	_listening = action
	_refresh_keys()
	_set_hint()


func _input(event: InputEvent) -> void:
	if _listening != "":
		if event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			if event.physical_keycode != KEY_ESCAPE:
				Settings.set_key(_listening, event.physical_keycode)
			_listening = ""
			_refresh_keys()
			_set_hint()
		elif event is InputEventMouseButton and event.pressed:
			get_viewport().set_input_as_handled()
			_listening = ""
			_refresh_keys()
			_set_hint()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _reset_all() -> void:
	Settings.reset_all()
	for r in _refreshers:
		r.call()
	_refresh_keys()


func close() -> void:
	closed.emit()
	queue_free()
