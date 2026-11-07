extends Control

const UIKit = preload("res://scripts/ui_kit.gd")
const Credits = preload("res://scripts/credits.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const GAME_SCENE := "res://scenes/main.tscn"

var _title: Label
var _backdrop: Control
var _stars: Array[Vector3] = []
var _embers: Array[Vector4] = []
var _t := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	theme = UIKit.make_theme()

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 90:
		_stars.append(Vector3(rng.randf(), rng.randf() * 0.6, rng.randf() * TAU))
	for i in 40:
		_embers.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(0.03, 0.09), rng.randf() * TAU))

	_backdrop = Control.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.draw.connect(_draw_backdrop)
	add_child(_backdrop)

	var box := UIKit.screen(self, Color(0, 0, 0, 0), false)
	box.add_theme_constant_override("separation", 16)
	box.add_child(UIKit.label("~  THE LANTERNS NEVER GO OUT  ~", 20, Color(UIKit.GOLD, 0.8)))
	_title = UIKit.title("Hollow Matsuri", 88)
	box.add_child(_title)
	box.add_child(UIKit.label("Win their games. Earn points. Open the gate and run.", 24, Color(0.75, 0.75, 0.8)))
	box.add_child(UIKit.divider(520))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	box.add_child(gap)

	var first: Button
	if SaveManager.has_save():
		first = UIKit.button("%s  -  %d pts" % [GameSettings.t("Continue"), SaveManager.peek_points()], _on_continue, true)
		box.add_child(first)
		box.add_child(UIKit.button(GameSettings.t("New game"), _on_new_game))
	else:
		first = UIKit.button(GameSettings.t("New game"), _on_new_game, true)
		box.add_child(first)
	var settings := SettingsPanel.new()
	box.add_child(UIKit.button(GameSettings.t("Settings"), settings.open))
	box.add_child(UIKit.button(GameSettings.t("Credits"), func(): add_child(Credits.new())))
	box.add_child(UIKit.button(GameSettings.t("Quit"), func(): get_tree().quit()))
	add_child(settings)
	settings.closed.connect(func(): get_tree().reload_current_scene.call_deferred())
	first.grab_focus.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	_backdrop.queue_redraw()
	var flick := 1.0 if fmod(_t, 4.3) > 0.25 else (0.35 if int(_t * 40.0) % 2 == 0 else 0.9)
	_title.modulate = Color(flick, flick, flick)


func _draw_backdrop() -> void:
	var s := _backdrop.size
	var bands := 24
	for i in bands:
		var c := UIKit.BG_TOP.lerp(UIKit.BG_BOTTOM, float(i) / (bands - 1))
		_backdrop.draw_rect(Rect2(0, s.y * i / bands, s.x, s.y / bands + 1.0), c)
	for st in _stars:
		var a := 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * 1.5 + st.z))
		_backdrop.draw_circle(Vector2(st.x * s.x, st.y * s.y), 1.5, Color(1, 1, 0.9, a))
	var moon := Vector2(s.x * 0.82, s.y * 0.2)
	_backdrop.draw_circle(moon, 70, Color(0.55, 0.6, 0.8, 0.12))
	_backdrop.draw_circle(moon, 46, Color(0.82, 0.85, 0.95))
	var x := -20.0
	var i := 0
	while x < s.x + 40.0:
		var h := 90.0 + 70.0 * absf(sin(i * 1.7)) + 25.0 * absf(sin(i * 0.37))
		var w := 60.0 + 26.0 * absf(sin(i * 2.3))
		_backdrop.draw_colored_polygon(PackedVector2Array([
			Vector2(x, s.y), Vector2(x + w / 2.0, s.y - h), Vector2(x + w, s.y)]), Color(0.01, 0.01, 0.02))
		x += w * 0.6
		i += 1
	for b in 3:
		var drift := sin(_t * 0.2 + b * 2.0) * 60.0
		_backdrop.draw_rect(Rect2(drift - 80.0, s.y * (0.78 + 0.07 * b), s.x + 160.0, 60.0), Color(0.3, 0.35, 0.4, 0.05))
	for e in _embers:
		var ey := fposmod(e.y - _t * e.z, 1.0)
		var ex := e.x + sin(_t * 0.7 + e.w) * 0.015
		var ea := sin(ey * PI) * (0.5 + 0.5 * sin(_t * 3.0 + e.w))
		_backdrop.draw_circle(Vector2(ex * s.x, ey * s.y), 2.5, Color(1.0, 0.55, 0.2, ea * 0.7))
		_backdrop.draw_circle(Vector2(ex * s.x, ey * s.y), 6.0, Color(1.0, 0.35, 0.1, ea * 0.12))
	for k in 8:
		var falloff := float(8 - k) / 8.0
		var edge := Color(0, 0, 0, 0.07 * falloff)
		var w := s.x * 0.12 * falloff
		_backdrop.draw_rect(Rect2(0, 0, w, s.y), edge)
		_backdrop.draw_rect(Rect2(s.x - w, 0, w, s.y), edge)


func _on_continue() -> void:
	SaveManager.load_game()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_new_game() -> void:
	SaveManager.new_game()
	get_tree().change_scene_to_file("res://scenes/intro.tscn")
