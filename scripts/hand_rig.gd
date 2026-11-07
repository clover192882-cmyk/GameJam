extends RefCounted
## Procedural first-person hand: palm, four jointed fingers, thumb, bare wrist and a dark sleeve.
## Fingers point along -Z and the forearm trails back along +Z (toward the camera).

const SKIN := Color(0.82, 0.66, 0.55)
const SLEEVE := Color(0.08, 0.08, 0.1)


static func _mat(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


static func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func make_hand(mirrored := false, skin := SKIN, sleeve := SLEEVE) -> Node3D:
	var root := Node3D.new()
	var s := _mat(skin, 0.55)
	var sl := _mat(sleeve, 0.9)
	_part(root, _box(Vector3(0.085, 0.028, 0.09)), Vector3.ZERO, s)
	var xs := [-0.03, -0.01, 0.01, 0.03]
	var lens := [0.05, 0.058, 0.054, 0.044]
	for i in 4:
		var l: float = lens[i]
		_part(root, _box(Vector3(0.018, 0.021, l)), Vector3(xs[i], -0.002, -0.045 - l / 2.0), s, Vector3(-8, 0, 0))
		_part(root, _box(Vector3(0.016, 0.019, l * 0.8)), Vector3(xs[i], -0.016, -0.045 - l - l * 0.32), s, Vector3(-38, 0, 0))
	_part(root, _box(Vector3(0.024, 0.022, 0.055)), Vector3(-0.055, -0.004, -0.012), s, Vector3(0, 38, 0))
	_part(root, _box(Vector3(0.062, 0.05, 0.1)), Vector3(0, 0.002, 0.095), s)
	_part(root, _box(Vector3(0.098, 0.082, 0.55)), Vector3(0, 0.008, 0.44), sl)
	_part(root, _box(Vector3(0.106, 0.09, 0.03)), Vector3(0, 0.008, 0.17), _mat(sleeve.lightened(0.12), 0.7))
	if mirrored:
		root.scale.x = -1.0
	return root
