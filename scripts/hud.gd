extends CanvasLayer

signal pause_requested

const UIKit = preload("res://scripts/ui_kit.gd")
const STALL_TITLES := {"dart": "Dart Balloon", "goldfish": "Goldfish Scooping", "cork": "Cork Gun Gallery"}

var _hearts: Array[Control] = []
var _progress_label: Label
var _progress_panel: Control

@onready var points_label: Label = $PointsLabel
@onready var game_over_label: Label = $GameOverLabel
@onready var prompt_label: Label = $PromptLabel


func _ready() -> void:
	PointManager.points_changed.connect(_on_points_changed)
	PointManager.game_over.connect(_on_game_over)
	game_over_label.hide()
	_style_labels()
	_build_progress_panel()
	_build_pause_button()
	_build_hearts()
	PointManager.health_changed.connect(_on_health_changed)
	StallManager.stall_unlocked.connect(func(_id): _refresh_progress())
	StallManager.stall_completed.connect(func(_id): _refresh_progress())
	StallManager.gate_opened.connect(_refresh_progress)
	DifficultyManager.difficulty_unlocked.connect(func(_id, _lv): _refresh_progress())
	DifficultyManager.selection_changed.connect(func(_id, _lv): _refresh_progress())
	_on_points_changed(PointManager.points, 0)


func _style_labels() -> void:
	points_label.text = "Points: 100"
	UIKit.pill(points_label)
	points_label.add_theme_font_size_override("font_size", 30)
	points_label.offset_left = 24.0
	points_label.offset_top = 16.0
	points_label.offset_right = 0.0
	points_label.offset_bottom = 0.0
	points_label.grow_horizontal = Control.GROW_DIRECTION_END
	points_label.grow_vertical = Control.GROW_DIRECTION_END
	UIKit.pill(prompt_label)
	prompt_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt_label.offset_top = -70.0
	prompt_label.offset_bottom = -50.0
	prompt_label.visible = false
	game_over_label.add_theme_font_size_override("font_size", 84)


class HeartIcon extends Control:
	var full := true:
		set(value):
			full = value
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(34, 34)

	func _draw() -> void:
		var c := Color(0.85, 0.12, 0.17) if full else Color(0.28, 0.28, 0.32)
		var s := 34.0
		draw_circle(Vector2(s * 0.3, s * 0.33), s * 0.24, c)
		draw_circle(Vector2(s * 0.7, s * 0.33), s * 0.24, c)
		draw_colored_polygon(PackedVector2Array([Vector2(s * 0.07, s * 0.42), Vector2(s * 0.93, s * 0.42), Vector2(s * 0.5, s * 0.92)]), c)
		if not full:
			draw_polyline(PackedVector2Array([Vector2(s * 0.5, s * 0.15), Vector2(s * 0.42, s * 0.4), Vector2(s * 0.58, s * 0.58), Vector2(s * 0.5, s * 0.85)]), Color.BLACK, 2.0)


func _build_hearts() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(24, 78)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for i in PointManager.MAX_HEALTH:
		var h := HeartIcon.new()
		row.add_child(h)
		_hearts.append(h)
	_on_health_changed(PointManager.health)


func _on_health_changed(new_health: int) -> void:
	for i in _hearts.size():
		_hearts[i].full = i < new_health


func _build_pause_button() -> void:
	var button := Button.new()
	button.text = "Pause (Esc)"
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", UIKit.CREAM)
	button.add_theme_stylebox_override("normal", UIKit.panel_style(Color(0.04, 0.07, 0.14, 0.75), Color(UIKit.GOLD, 0.5), 12, 6))
	button.add_theme_stylebox_override("hover", UIKit.panel_style(UIKit.RED, UIKit.GOLD, 12, 6))
	button.add_theme_stylebox_override("pressed", UIKit.panel_style(UIKit.RED_DARK, UIKit.GOLD, 12, 6))
	button.anchor_left = 0.5
	button.anchor_right = 0.5
	button.offset_left = -75.0
	button.offset_right = 75.0
	button.offset_top = 12.0
	button.offset_bottom = 52.0
	button.pressed.connect(func(): pause_requested.emit())
	add_child(button)

	var hint := Label.new()
	hint.text = "Hold Tab to show the cursor  |  V: change view"
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.offset_left = -220.0
	hint.offset_right = 220.0
	hint.offset_top = 54.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 0.75))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 4)
	add_child(hint)


# The panel sizes itself to its text and grows leftwards from the right edge, so nothing is clipped.
func _build_progress_panel() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -16.0
	panel.offset_right = -16.0
	panel.offset_top = 12.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.04, 0.07, 0.14, 0.72), Color(UIKit.GOLD, 0.45), 14, 12))
	add_child(panel)
	_progress_panel = panel

	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress_label.add_theme_font_size_override("font_size", 18)
	_progress_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	panel.add_child(_progress_label)


func set_progress_visible(shown: bool) -> void:
	_progress_panel.visible = shown


func _refresh_progress() -> void:
	var lines: Array[String] = []
	for id in ["dart", "goldfish", "cork"]:
		var title: String = STALL_TITLES[id]
		if not StallManager.is_unlocked(id):
			lines.append("%s - locked, %d pts" % [title, StallManager.cost_of(id)])
			continue
		var mark := "[done] " if StallManager.is_completed(id) else ""
		var line := "%s%s - %s" % [mark, title, DifficultyManager.level_name(DifficultyManager.selected(id))]
		var next_cost := DifficultyManager.next_unlock_cost(id)
		if next_cost >= 0:
			line += " | next level %d pts" % next_cost
		lines.append(line)
	if StallManager.gate_open:
		lines.append("Gate - OPEN, walk out to win")
	else:
		lines.append("Gate - locked, %d pts" % StallManager.GATE_COST)
	_progress_label.text = "\n".join(lines)


func _on_points_changed(new_points: int, _delta: int) -> void:
	points_label.text = "Points: %d" % new_points
	_refresh_progress()


func _on_game_over() -> void:
	game_over_label.show()


func set_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = text != ""


# Hold Tab to free the cursor so the Pause button can be clicked; release to look around again.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or event.echo or event.keycode != KEY_TAB:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if event.pressed else Input.MOUSE_MODE_CAPTURED
	get_viewport().set_input_as_handled()
