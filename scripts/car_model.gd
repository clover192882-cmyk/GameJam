extends RefCounted

const Build = preload("res://scripts/build.gd")
const MODEL_PATH := "res://assets/models/car.glb"


# Returns a node whose local -Z is the car's front, sitting on y = 0 and centred on x/z.
static func make(length := 4.4) -> Node3D:
	var wrapper := Node3D.new()
	var scene = load(MODEL_PATH) if ResourceLoader.exists(MODEL_PATH) else null
	if not scene is PackedScene:
		_fallback(wrapper)
		return wrapper
	var inst: Node3D = scene.instantiate()
	var bb := _bounds(inst, Transform3D.IDENTITY)
	var angle := PI
	if bb.size.x > bb.size.z:
		angle += PI / 2.0
	var rot := Transform3D(Basis(Vector3.UP, angle), Vector3.ZERO)
	var rb: AABB = rot * bb
	var s := length / maxf(rb.size.z, 0.001)
	var pivot := Node3D.new()
	pivot.rotation.y = angle
	pivot.scale = Vector3.ONE * s
	var c := rb.get_center()
	pivot.position = Vector3(-c.x * s, -rb.position.y * s, -c.z * s)
	wrapper.add_child(pivot)
	pivot.add_child(inst)
	return wrapper


static func add_headlights(car: Node3D, on := true) -> Array[SpotLight3D]:
	var lights: Array[SpotLight3D] = []
	for x in [-0.6, 0.6]:
		var spot := SpotLight3D.new()
		spot.position = Vector3(x, 0.7, -2.0)
		spot.spot_range = 30.0
		spot.spot_angle = 28.0
		spot.light_energy = 6.0
		spot.light_color = Color(1.0, 0.95, 0.8)
		spot.visible = on
		car.add_child(spot)
		lights.append(spot)
	return lights


static func _bounds(node: Node, xf: Transform3D) -> AABB:
	var result := AABB()
	var have := false
	if node is MeshInstance3D and node.mesh:
		result = xf * node.mesh.get_aabb()
		have = true
	for child in node.get_children():
		if child is Node3D:
			var b := _bounds(child, xf * child.transform)
			if b.size != Vector3.ZERO:
				result = result.merge(b) if have else b
				have = true
	return result


static func _fallback(car: Node3D) -> void:
	Build.box(car, Vector3(0, 0.6, 0), Vector3(1.9, 1.0, 4.0), Color(0.08, 0.09, 0.12), true)
	Build.box(car, Vector3(0, 1.4, 0.2), Vector3(1.7, 0.7, 2.0), Color(0.06, 0.07, 0.1), true)
