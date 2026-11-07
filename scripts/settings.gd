extends Node

signal changed

const PATH := "user://settings.cfg"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
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

var master := 1.0
var music := 1.0
var sfx := 1.0
var sensitivity := 1.0
var invert_y := false

# Graphics. Choice settings are stored as an index into their option list.
const DISPLAY_MODES := ["Windowed", "Maximized", "Fullscreen"]
const FPS_CAPS := [0, 30, 60, 120, 144]
const MSAA_NAMES := ["Off", "2x", "4x"]
const SHADOW_NAMES := ["Off", "Low", "Medium", "High"]
const SHADOW_SIZES := [1024, 1024, 2048, 4096]

var display_mode := 1
var vsync := true
var fps_cap := 0
var render_scale := 1.0
var msaa := 1
var shadows := 2
var glow := true
var brightness := 1.0
var fov := 75.0
var head_bob := true

const GRAPHICS := {
	"display_mode": [0, 2], "vsync": [false, true], "fps_cap": [0, 4], "render_scale": [0.5, 1.0],
	"msaa": [0, 2], "shadows": [0, 3], "glow": [false, true], "brightness": [0.6, 1.6],
	"fov": [60.0, 100.0], "head_bob": [false, true],
}
const GRAPHICS_DEFAULTS := {
	"display_mode": 1, "vsync": true, "fps_cap": 0, "render_scale": 1.0, "msaa": 1, "shadows": 2,
	"glow": true, "brightness": 1.0, "fov": 75.0, "head_bob": true,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	reset_keys(false)
	_load()
	_apply_audio()
	apply_graphics()
	get_tree().node_added.connect(_on_node_added)


func _apply_audio() -> void:
	_set_bus("Master", master)
	_set_bus(MUSIC_BUS, music)
	_set_bus(SFX_BUS, sfx)


func _set_bus(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(i, linear <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.001)))


func set_volume(which: String, value: float) -> void:
	set(which, clampf(value, 0.0, 1.0))
	_apply_audio()
	_save()
	changed.emit()


func set_graphic(prop: String, value) -> void:
	var limits: Array = GRAPHICS[prop]
	if value is bool:
		set(prop, value)
	elif prop in ["display_mode", "fps_cap", "msaa", "shadows"]:
		set(prop, clampi(int(value), limits[0], limits[1]))
	else:
		set(prop, clampf(float(value), limits[0], limits[1]))
	apply_graphics()
	_save()
	changed.emit()


# Window and rendering options act on the root viewport, so they work on every screen.
func apply_graphics() -> void:
	var root := get_tree().root
	var modes := [DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_MAXIMIZED, DisplayServer.WINDOW_MODE_FULLSCREEN]
	var mode: DisplayServer.WindowMode = modes[display_mode]
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = FPS_CAPS[fps_cap]
	root.scaling_3d_scale = render_scale
	root.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][msaa]
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_SIZES[shadows], true)
	_apply_scene(root)


# The world environment and the moon only exist in the game scene, so they are tuned as they appear.
func _on_node_added(node: Node) -> void:
	if node is WorldEnvironment or (node is DirectionalLight3D and node.name == "Moon"):
		_apply_node.call_deferred(node)


func _apply_scene(from: Node) -> void:
	if from is WorldEnvironment or (from is DirectionalLight3D and from.name == "Moon"):
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


func set_sensitivity(value: float) -> void:
	sensitivity = clampf(value, 0.2, 3.0)
	_save()
	changed.emit()


func set_invert_y(on: bool) -> void:
	invert_y = on
	_save()
	changed.emit()


func key_of(action: String) -> int:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return e.physical_keycode
	return KEY_NONE


func key_name(action: String) -> String:
	return code_name(key_of(action))


func code_name(code: int) -> String:
	if code == KEY_NONE:
		return "-"
	var k := DisplayServer.keyboard_get_keycode_from_physical(code as Key)
	return OS.get_keycode_string(k if k != KEY_NONE else code)


func movement_name() -> String:
	return " ".join(["move_forward", "move_left", "move_back", "move_right"].map(key_name))


func is_movement_key(code: int) -> bool:
	for a in ["move_forward", "move_left", "move_back", "move_right"]:
		if key_of(a) == code:
			return true
	return false


# Returns false for keys that can't be used (Esc pauses, Tab shows the cursor).
func set_key(action: String, code: int) -> bool:
	if code in RESERVED_KEYS or code == KEY_NONE:
		return false
	var old := key_of(action)
	for b in BINDINGS:
		if b[0] != action and key_of(b[0]) == code:
			_bind(b[0], old)
	_bind(action, code)
	_save()
	changed.emit()
	return true


func reset_keys(save := true) -> void:
	for b in BINDINGS:
		_bind(b[0], b[2])
	if save:
		_save()
		changed.emit()


func reset_all() -> void:
	master = 1.0
	music = 1.0
	sfx = 1.0
	sensitivity = 1.0
	invert_y = false
	for k in GRAPHICS_DEFAULTS:
		set(k, GRAPHICS_DEFAULTS[k])
	_apply_audio()
	apply_graphics()
	reset_keys(false)
	_save()
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


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("input", "sensitivity", sensitivity)
	cfg.set_value("input", "invert_y", invert_y)
	for k in GRAPHICS_DEFAULTS:
		cfg.set_value("graphics", k, get(k))
	for b in BINDINGS:
		cfg.set_value("keys", b[0], key_of(b[0]))
	cfg.save(PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	master = clampf(float(cfg.get_value("audio", "master", 1.0)), 0.0, 1.0)
	music = clampf(float(cfg.get_value("audio", "music", 1.0)), 0.0, 1.0)
	sfx = clampf(float(cfg.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
	sensitivity = clampf(float(cfg.get_value("input", "sensitivity", 1.0)), 0.2, 3.0)
	invert_y = bool(cfg.get_value("input", "invert_y", false))
	for k in GRAPHICS_DEFAULTS:
		var v = cfg.get_value("graphics", k, GRAPHICS_DEFAULTS[k])
		if typeof(v) == typeof(GRAPHICS_DEFAULTS[k]) or (v is float and GRAPHICS_DEFAULTS[k] is int) or (v is int and GRAPHICS_DEFAULTS[k] is float):
			var limits: Array = GRAPHICS[k]
			if GRAPHICS_DEFAULTS[k] is bool:
				set(k, v)
			elif GRAPHICS_DEFAULTS[k] is int:
				set(k, clampi(int(v), limits[0], limits[1]))
			else:
				set(k, clampf(float(v), limits[0], limits[1]))
	for b in BINDINGS:
		var code := int(cfg.get_value("keys", b[0], b[2]))
		if code != KEY_NONE and not code in RESERVED_KEYS:
			_bind(b[0], code)
