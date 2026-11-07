extends ColorRect

signal closed

const UIKit = preload("res://scripts/ui_kit.gd")
const Translations = preload("res://scripts/translations.gd")
const TABS := ["Audio", "Controls", "Graphics", "Language"]
const PAGE_SIZE := Vector2(940, 310)
const COLUMN_W := 440.0

var _tab := 0
var _listening := ""
var _key_buttons := {}
var _refreshers: Array[Callable] = []
var _back_btn: Button
var _hint: Label
var _root: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	color = Color(0, 0, 0, 0.78)
	theme = UIKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false


func open() -> void:
	_rebuild()
	visible = true
	_back_btn.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	_listening = ""
	GameSettings.save_settings()
	closed.emit()


func _rebuild() -> void:
	if _root:
		_root.queue_free()
		_root = null
	_build()
	if visible:
		_back_btn.grab_focus.call_deferred()


func _build() -> void:
	_key_buttons.clear()
	_refreshers.clear()
	_root = Control.new()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.panel_style(UIKit.INK, UIKit.TRIM, 12, 20))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	box.add_child(UIKit.title(GameSettings.t("Settings"), 44))
	box.add_child(UIKit.divider())

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	box.add_child(tabs)
	var pages: Array[Control] = []
	var holder := Control.new()
	holder.custom_minimum_size = PAGE_SIZE
	for i in TABS.size():
		var tb := UIKit.button(GameSettings.t(TABS[i]), _show_tab.bind(i, pages, tabs))
		_slim(tb, 176, 40, 22)
		tabs.add_child(tb)
	box.add_child(holder)
	for page in [_build_audio(), _build_controls(), _build_graphics(), _build_language()]:
		holder.add_child(page)
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pages.append(page)

	_hint = UIKit.label("", 16, Color(UIKit.CREAM, 0.7))
	box.add_child(_hint)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	box.add_child(buttons)
	var reset := UIKit.button(GameSettings.t("Reset"), _on_reset)
	_slim(reset, 220, 46, 24)
	buttons.add_child(reset)
	_back_btn = UIKit.button(GameSettings.t("Back"), close, true)
	_slim(_back_btn, 220, 46, 24)
	buttons.add_child(_back_btn)
	_show_tab(_tab, pages, tabs)


func _slim(b: Button, w: float, h: float, font: int) -> void:
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", font)
	for st in ["normal", "hover", "pressed", "focus"]:
		var s: StyleBoxFlat = b.get_theme_stylebox(st).duplicate()
		s.set_content_margin_all(2)
		b.add_theme_stylebox_override(st, s)


func _show_tab(index: int, pages: Array[Control], tabs: Control) -> void:
	_tab = index
	_listening = ""
	_refresh_keys()
	for i in pages.size():
		pages[i].visible = i == index
		tabs.get_child(i).modulate = Color(1, 1, 1) if i == index else Color(0.65, 0.65, 0.7)
	_set_hint()


func _page(title: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	var h := UIKit.label(GameSettings.t(title).to_upper(), 20, Color(UIKit.GOLD, 0.8))
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(h)
	return col


func _build_audio() -> Control:
	var col := _page("Audio")
	col.add_child(_slider("Master Volume", "master", 0.0, 1.0, _percent))
	col.add_child(_slider("Music", "music", 0.0, 1.0, _percent))
	col.add_child(_slider("Effects", "sfx", 0.0, 1.0, _percent))
	return col


func _build_controls() -> Control:
	var col := _page("Controls")
	col.add_child(_slider("Mouse Sensitivity", "mouse_sens", 0.2, 3.0, func(v): return "x%.2f" % v))
	col.add_child(_toggle("Invert Look", "invert_y"))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	for b in GameSettings.BINDINGS:
		var name_l := UIKit.label(GameSettings.t(b[1]), 16)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_l.custom_minimum_size = Vector2(160, 0)
		grid.add_child(name_l)
		var kb := UIKit.button("", _listen.bind(b[0]))
		_slim(kb, 110, 30, 16)
		grid.add_child(kb)
		_key_buttons[b[0]] = kb
	var reset_keys := UIKit.button(GameSettings.t("Reset keys"), func():
		GameSettings.reset_keys()
		_refresh_keys())
	_slim(reset_keys, 200, 34, 18)
	col.add_child(reset_keys)
	_refresh_keys()
	return col


func _build_graphics() -> Control:
	var page := HBoxContainer.new()
	page.add_theme_constant_override("separation", 40)
	var left := _page("Graphics")
	left.custom_minimum_size = Vector2(COLUMN_W, 0)
	left.add_child(_cycler("Window Mode", "display_mode", GameSettings.DISPLAY_MODES))
	left.add_child(_toggle("Vertical Sync", "vsync"))
	left.add_child(_cycler("Frame Rate Limit", "fps_cap", GameSettings.FPS_CAPS.map(func(f): return "Unlimited" if f == 0 else "%d" % f)))
	left.add_child(_slider("Field of View", "fov", 60.0, 100.0, func(v): return "%d" % roundi(v)))
	left.add_child(_toggle("Head Bob", "head_bob"))
	var right := _page("")
	right.custom_minimum_size = Vector2(COLUMN_W, 0)
	right.add_child(_slider("Render Scale", "render_scale", 0.5, 1.0, _percent))
	right.add_child(_cycler("Anti-aliasing", "msaa", GameSettings.MSAA_NAMES))
	right.add_child(_cycler("Shadows", "shadows", GameSettings.SHADOW_NAMES))
	right.add_child(_toggle("Glow", "glow"))
	right.add_child(_slider("Brightness", "brightness", 0.6, 1.6, _percent))
	page.add_child(left)
	page.add_child(right)
	return page


func _build_language() -> Control:
	var col := _page("Language")
	col.add_child(_cycler("Language", "language", Translations.NAMES, false))
	var note := UIKit.label(GameSettings.t("Language changes apply to menus and settings."), 16, Color(UIKit.CREAM, 0.6))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(note)
	return col


static func _percent(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


func _row_label(text: String) -> Label:
	var l := UIKit.label(GameSettings.t(text), 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _slider(title: String, prop: String, lo: float, hi: float, fmt: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var name_l := _row_label(title)
	name_l.custom_minimum_size = Vector2(170, 0)
	name_l.size_flags_horizontal = Control.SIZE_FILL
	row.add_child(name_l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.focus_mode = Control.FOCUS_ALL
	s.custom_minimum_size = Vector2(110, 30)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value = GameSettings.get(prop)
	row.add_child(s)
	var val := UIKit.label(fmt.call(s.value), 20, UIKit.GOLD)
	val.custom_minimum_size = Vector2(64, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	s.value_changed.connect(func(v: float):
		val.text = fmt.call(v)
		GameSettings.set_value(prop, v))
	_refreshers.append(func():
		s.set_value_no_signal(GameSettings.get(prop))
		val.text = fmt.call(s.value))
	return row


func _toggle(title: String, prop: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.add_child(_row_label(title))
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(90, 34)
	b.add_theme_font_size_override("font_size", 18)
	b.focus_mode = Control.FOCUS_ALL
	var show := func():
		b.set_pressed_no_signal(GameSettings.get(prop))
		b.text = GameSettings.t("ON" if b.button_pressed else "OFF")
	b.toggled.connect(func(on: bool):
		GameSettings.set_value(prop, on)
		show.call())
	show.call()
	_refreshers.append(show)
	row.add_child(b)
	return row


func _cycler(title: String, prop: String, names: Array, translate := true) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_row_label(title))
	var val := UIKit.label("", 20, UIKit.GOLD)
	val.custom_minimum_size = Vector2(110, 0)
	var show := func():
		var n := str(names[GameSettings.get(prop)])
		val.text = GameSettings.t(n) if translate else n
	var step := func(d: int):
		GameSettings.set_value(prop, posmod(int(GameSettings.get(prop)) + d, names.size()))
		show.call()
		if prop == "language":
			_rebuild.call_deferred()
	var prev := UIKit.button("<", func(): step.call(-1))
	var next := UIKit.button(">", func(): step.call(1))
	for b in [prev, next]:
		_slim(b, 40, 32, 20)
	row.add_child(prev)
	row.add_child(val)
	row.add_child(next)
	show.call()
	_refreshers.append(show)
	return row


func _refresh_keys() -> void:
	for action in _key_buttons:
		_key_buttons[action].text = GameSettings.t("Press a key...") if action == _listening else GameSettings.key_name(action)


func _set_hint() -> void:
	if not _hint:
		return
	if _listening != "":
		_hint.text = GameSettings.t("Press the new key, or Esc to cancel")
	elif _tab == 1:
		_hint.text = GameSettings.t("Click a key to change it")
	else:
		_hint.text = ""


func _listen(action: String) -> void:
	_listening = action
	_refresh_keys()
	_set_hint()


func _on_reset() -> void:
	var cats := ["audio", "controls", "graphics", "language"]
	GameSettings.reset_category(cats[_tab])
	_rebuild.call_deferred()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _listening != "":
		if event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			if event.physical_keycode != KEY_ESCAPE:
				GameSettings.set_key(_listening, event.physical_keycode)
			_listening = ""
			_refresh_keys()
			_set_hint()
		elif event is InputEventMouseButton and event.pressed:
			get_viewport().set_input_as_handled()
			_listening = ""
			_refresh_keys()
			_set_hint()
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close()
