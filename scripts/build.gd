extends RefCounted

static var _mat_cache := {}
static var _mesh_cache := {}


static func _material(color: Color, glow: float) -> StandardMaterial3D:
	var key := [color, glow]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cache[key] = mat
	return mat


static func _box_mesh(size: Vector3) -> BoxMesh:
	if _mesh_cache.has(size):
		return _mesh_cache[size]
	var bm := BoxMesh.new()
	bm.size = size
	_mesh_cache[size] = bm
	return bm


static func box(parent: Node, pos: Vector3, size: Vector3, color: Color, collide := false, glow := 0.0) -> Node3D:
	var root: Node3D
	if collide:
		root = StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		root.add_child(shape)
	else:
		root = Node3D.new()
	root.position = pos

	var mesh := MeshInstance3D.new()
	mesh.mesh = _box_mesh(size)
	mesh.material_override = _material(color, glow)
	root.add_child(mesh)

	parent.add_child(root)
	return root


static func invisible_wall(parent: Node, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	parent.add_child(body)


static func lantern(parent: Node, pos: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.42
	mesh.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mesh.material_override = mat
	mesh.position = pos
	parent.add_child(mesh)
