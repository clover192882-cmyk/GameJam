extends Node

signal changed

const Translations = preload("res://scripts/translations.gd")
const PATH := "user://settings.cfg"
const BUSES := ["Music", "SFX"]
const RESERVED_KEYS := [KEY_ESCAPE, KEY_TAB]

# [action, label, default physical key]
const BINDINGS := [
	["move_forward", "Move forward", KEY_W],
	["move_back", "Move back", KEY_S],
	["move_left", "Move left", KEY_A],
	["move_right", "Move right", KEY_D],
	["jump", "Jump", KEY_SPACE],
	["interact", "Interact", KEY_E],
	["difficulty_cycle", "Change difficulty", KEY_Q],
	["difficulty_unlock", "Unlock level", KEY_R],
	["toggle_view", "Change view", KEY_V],
]

const DISPLAY_MODES := ["Windowed", "Fullscreen"]
const FPS_CAPS := [0, 30, 60, 120, 144]
const MSAA_NAMES := ["Off", "2x", "4x"]
const SHADOW_NAMES := ["Off", "Low", "Medium", "High"]
const SHADOW_SIZES := [1024, 1024, 2048, 4096]

# Every option except key bindings: category, default, [min, max].
const OPTIONS := {
	"master": ["audio", 1.0, [0.0, 1.0]],
	"music": ["audio", 1.0, [0.0, 1.0]],
	"sfx": ["audio", 1.0, [0.0, 1.0]],
	"mouse_sens": ["controls", 1.0, [0.2, 3.0]],
	"invert_y": ["controls", false, [false, true]],
	"display_mode": ["graphics", 0, [0, 1]],
	"vsync": ["graphics", true, [false, true]],
	"fps_cap": ["graphics", 0, [0, 4]],
	"render_scale": ["graphics", 1.0, [0.5, 1.0]],
	"msaa": ["graphics", 1, [0, 2]],
	"shadows": ["graphics", 2, [0, 3]],
	"glow": ["graphics", true, [false, true]],
	"brightness": ["graphics", 1.0, [0.6, 1.6]],
	"fov": ["graphics", 75.0, [60.0, 100.0]],
	"head_bob": ["graphics", true, [false, true]],
	"language": ["language", 0, [0, 2]],
}

var master := 1.0
var music := 1.0
var sfx := 1.0
var mouse_sens := 1.0
var invert_y := false
var display_mode := 0
var vsync := true
var fps_cap := 0
var render_scale := 1.0
var msaa := 1
var shadows := 2
var glow := true
var brightness := 1.0
var fov := 75.0
var head_bob := true
var language := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	reset_keys(false)
	load_settings()
	apply()
	get_tree().node_added.connect(_on_node_added)


func t(text: String) -> String:
	return Translations.tr_text(Translations.CODES[language], text)


func set_value(prop: String, value) -> void:
	var def = OPTIONS[prop][1]
	var limits: Array = OPTIONS[prop][2]
	if def is bool:
		set(prop, bool(value))
	elif def is int:
		set(prop, clampi(int(value), limits[0], limits[1]))
	else:
		set(prop, clampf(float(value), limits[0], limits[1]))
	apply()
	save_settings()


func apply() -> void:
	_set_bus("Master", master)
	_set_bus("Music", music)
	_set_bus("SFX", sfx)
	var root := get_tree().root
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if display_mode == 1 else DisplayServer.WINDOW_MODE_WINDOWED
	var current := DisplayServer.window_get_mode()
	var is_full := current == DisplayServer.WINDOW_MODE_FULLSCREEN or current == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if (display_mode == 1) != is_full:
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = FPS_CAPS[fps_cap]
	root.scaling_3d_scale = render_scale
	root.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][msaa]
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_SIZES[shadows], true)
	_apply_scene(root)
	changed.emit()


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))


# The world environment and the moon only exist in the game scene, so they are tuned as they appear.
func _on_node_added(node: Node) -> void:
	if _is_scene_target(node):
		_apply_node.call_deferred(node)


func _is_scene_target(node: Node) -> bool:
	return node is WorldEnvironment or (node is DirectionalLight3D and node.name == "Moon")


func _apply_scene(from: Node) -> void:
	if _is_scene_target(from):
		_apply_node(from)
	for c in from.get_children():
		_apply_scene(c)


func _apply_node(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is WorldEnvironment and node.environment:
		node.environment.glow_enabled = glow
		node.environment.adjustment_enabled = true
		node.environment.adjustment_brightness = brightness
	elif node is DirectionalLight3D:
		node.shadow_enabled = shadows > 0


func key_of(action: String) -> int:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return e.physical_keycode
	return KEY_NONE


func key_name(action: String) -> String:
	var code := key_of(action)
	if code == KEY_NONE:
		return "-"
	var k := DisplayServer.keyboard_get_keycode_from_physical(code as Key)
	return OS.get_keycode_string(k if k != KEY_NONE else code)


# Returns false for keys that can't be used (Esc pauses, Tab shows the cursor).
func set_key(action: String, code: int) -> bool:
	if code in RESERVED_KEYS or code == KEY_NONE:
		return false
	var old := key_of(action)
	for b in BINDINGS:
		if b[0] != action and key_of(b[0]) == code:
			_bind(b[0], old)
	_bind(action, code)
	save_settings()
	changed.emit()
	return true


func reset_keys(save := true) -> void:
	for b in BINDINGS:
		_bind(b[0], b[2])
	if save:
		save_settings()
		changed.emit()


# Jump and the minigame action share a key so a round can be played with the same button.
func _bind(action: String, code: int) -> void:
	var actions := [action]
	if action == "jump":
		actions.append("minigame_action")
	for a in actions:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		InputMap.action_erase_events(a)
		var ev := InputEventKey.new()
		ev.physical_keycode = code as Key
		InputMap.action_add_event(a, ev)


func reset_category(category: String) -> void:
	for k in OPTIONS:
		if OPTIONS[k][0] == category:
			set(k, OPTIONS[k][1])
	if category == "controls":
		reset_keys(false)
	apply()
	save_settings()


func reset_defaults() -> void:
	for k in OPTIONS:
		set(k, OPTIONS[k][1])
	reset_keys(false)
	apply()
	save_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in OPTIONS:
		cfg.set_value(OPTIONS[k][0], k, get(k))
	for b in BINDINGS:
		cfg.set_value("keys", b[0], key_of(b[0]))
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in OPTIONS:
		var def = OPTIONS[k][1]
		var limits: Array = OPTIONS[k][2]
		var v = cfg.get_value(OPTIONS[k][0], k, def)
		if def is bool:
			set(k, bool(v))
		elif def is int:
			set(k, clampi(int(v), limits[0], limits[1]))
		else:
			set(k, clampf(float(v), limits[0], limits[1]))
	for b in BINDINGS:
		var code := int(cfg.get_value("keys", b[0], b[2]))
		if code != KEY_NONE and not code in RESERVED_KEYS:
			_bind(b[0], code)
