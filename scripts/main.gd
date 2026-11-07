extends Node3D

const PauseMenu = preload("res://scripts/pause_menu.gd")
const TouchControls = preload("res://scripts/touch_controls.gd")
const StressFX = preload("res://scripts/stress_fx.gd")

@onready var player = $Player
@onready var hud = $HUD
@onready var minigames = $MinigameManager
@onready var game_manager = $GameManager


func _ready() -> void:
	player.position = Vector3(10.2, 0.1, 0)
	player.rotation.y = PI / 2.0
	game_manager.player = player
	game_manager.hud = hud
	minigames.player = player
	minigames.audio = $AudioManager
	var pause_menu := PauseMenu.new()
	pause_menu.game_manager = game_manager
	pause_menu.minigames = minigames
	add_child(pause_menu)
	var stress := StressFX.new()
	stress.player = player
	add_child(stress)
	var touch := TouchControls.new()
	touch.player = player
	add_child(touch)
	hud.pause_requested.connect(pause_menu.open)
	minigames.round_started.connect(hud.set_progress_visible.bind(false))
	minigames.round_ended.connect(hud.set_progress_visible.bind(true))
	player.interaction.prompt_changed.connect(hud.set_prompt)
	player.interaction.interacted.connect(_on_interacted)


func _on_interacted(target: Node) -> void:
	if target.is_in_group("gate"):
		target.interact()
	else:
		minigames.start_for_stall(target)
