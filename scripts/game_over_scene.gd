extends Node3D

const Build = preload("res://scripts/build.gd")
const ORIGIN := Vector3(0, 0, 60)
const CAM_POS := Vector3(0, 3.6, 0)

signal finished

var _cam: Camera3D
var _flash: ColorRect
var _guard: Node3D
var _arm: Node3D
var _plank: Node3D
var _balloon: MeshInstance3D


func _ready() -> void:
	position = ORIGIN
	_build_stage()
	_build_bucket()
	_build_guard()

	_cam = Camera3D.new()
	_cam.position = CAM_POS
	_cam.rotation_degrees.x = -12
	add_child(_cam)

	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(0.4, 0.7, 1.0, 0.0)
	layer.add_child(_flash)


func begin() -> void:
	_cam.make_current()


func play() -> void:
	await get_tree().create_timer(1.5).timeout
	_guard.show()
	_guard.scale = Vector3.ONE * 0.01
	var pop := create_tween()
	pop.tween_property(_guard, "scale", Vector3.ONE, 0.2)
	await pop.finished
	await get_tree().create_timer(1.0).timeout

	var windup := create_tween()
	windup.tween_property(_arm, "rotation:x", 2.1, 0.6)
	await windup.finished
	var throw_tween := create_tween()
	throw_tween.tween_property(_arm, "rotation:x", -2.1, 0.25)
	await get_tree().create_timer(0.12).timeout
	await _throw_balloon()

	_flash.color.a = 0.9
	var fade := create_tween()
	fade.tween_property(_flash, "color:a", 0.0, 0.8)
	_balloon.hide()
	_plank.hide()

	var fall := create_tween().set_parallel(true)
	fall.tween_property(_cam, "position:y", 0.7, 1.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	fall.tween_property(_cam, "rotation_degrees:x", 70.0, 1.0)
	await fall.finished

	_flash.color.a = 0.7
	var splash := create_tween()
	splash.tween_property(_flash, "color:a", 0.0, 0.7)
	await get_tree().create_timer(1.2).timeout
	finished.emit()


func _throw_balloon() -> void:
	_balloon = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	_balloon.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.6, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.5, 1.0)
	mat.emission_energy_multiplier = 0.8
	_balloon.material_override = mat
	add_child(_balloon)

	var from := Vector3(0.55, 2.0, -5.6)
	var to := CAM_POS + Vector3(0, -0.2, -0.4)
	var tween := create_tween()
	tween.tween_method(func(t: float):
		_balloon.position = from.lerp(to, t) + Vector3(0, sin(PI * t) * 1.2, 0), 0.0, 1.0, 0.7)
	await tween.finished


func _build_stage() -> void:
	Build.box(self, Vector3(0, -0.2, -3), Vector3(12, 0.4, 14), Color(0.5, 0.12, 0.14))
	Build.box(self, Vector3(0, 3, -10.2), Vector3(12, 6, 0.3), Color(0.28, 0.06, 0.09))
	for i in 7:
		var x := lerpf(-5.0, 5.0, i / 6.0)
		Build.lantern(self, Vector3(x, 5.2, -9.8), Color(1.0, 0.35, 0.2) if i % 2 == 0 else Color(1.0, 0.85, 0.3))

	var banner := Label3D.new()
	banner.text = "TRY AGAIN!"
	banner.font_size = 128
	banner.pixel_size = 0.01
	banner.modulate = Color(1.0, 0.9, 0.5)
	banner.position = Vector3(0, 4.2, -9.9)
	add_child(banner)

	var warm := OmniLight3D.new()
	warm.position = Vector3(0, 5, -3)
	warm.light_color = Color(1.0, 0.85, 0.6)
	warm.light_energy = 3.0
	warm.omni_range = 16.0
	add_child(warm)
	var bucket_light := OmniLight3D.new()
	bucket_light.position = Vector3(0, 3, 1)
	bucket_light.light_energy = 1.5
	bucket_light.omni_range = 6.0
	add_child(bucket_light)


func _build_bucket() -> void:
	var bucket := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.1
	cyl.bottom_radius = 0.9
	cyl.height = 2.0
	cyl.cap_top = false
	bucket.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.4, 0.8)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bucket.material_override = mat
	bucket.position = Vector3(0, 1.0, 0)
	add_child(bucket)

	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	water.mesh = disc
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.4, 0.75, 1.0)
	water_mat.emission_enabled = true
	water_mat.emission = Color(0.2, 0.5, 0.9)
	water_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	water.material_override = water_mat
	water.position = Vector3(0, 1.4, 0)
	add_child(water)

	_plank = Build.box(self, Vector3(0, 2.0, 0), Vector3(1.6, 0.1, 0.8), Color(0.45, 0.3, 0.15))


func _build_guard() -> void:
	_guard = Node3D.new()
	_guard.position = Vector3(0, 0, -6)
	_guard.hide()
	add_child(_guard)

	var black := Color(0.04, 0.04, 0.05)
	Build.box(_guard, Vector3(0, 0.4, 0), Vector3(0.6, 0.8, 0.35), black)
	Build.box(_guard, Vector3(0, 1.3, 0), Vector3(0.9, 1.0, 0.5), black)
	Build.box(_guard, Vector3(0, 2.08, 0.22), Vector3(0.4, 0.08, 0.05), Color(0.0, 0.0, 0.0))
	Build.box(_guard, Vector3(-0.55, 1.2, 0), Vector3(0.18, 0.8, 0.18), black)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.25
	head_mesh.height = 0.5
	head.mesh = head_mesh
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.85, 0.7, 0.6)
	head.material_override = head_mat
	head.position = Vector3(0, 2.05, 0)
	_guard.add_child(head)

	_arm = Node3D.new()
	_arm.position = Vector3(0.55, 1.7, 0)
	_guard.add_child(_arm)
	Build.box(_arm, Vector3(0, -0.4, 0), Vector3(0.18, 0.8, 0.18), black)
