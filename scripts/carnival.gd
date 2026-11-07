extends Node3D

const Build = preload("res://scripts/build.gd")
const Gate = preload("res://scripts/gate.gd")
const CarModel = preload("res://scripts/car_model.gd")
const Fireflies = preload("res://scripts/fireflies.gd")

const ROAD_X := 28.0
const ROAD_W := 6.0
const CAR_POS := Vector2(23.6, 0.0)
const FOREST_TREES := 700
const FOREST_BUSHES := 350
const FOREST_PINES := 450
const PINE_PATH := "res://assets/models/pine.glb"
const PINE_HEIGHT := 5.5

const HALF_X := 12.0
const HALF_Z := 9.0
const FENCE_H := 2.8
const BAR_SPACING := 0.45
const WALL_H := 6.0
const IRON := Color(0.1, 0.1, 0.12)
const STONE := Color(0.42, 0.4, 0.38)
const ROAD := Color(0.45, 0.4, 0.33)
const MOON_DIR := Vector3(-0.45, 0.62, 0.6)
const HUB := Vector2(6.5, 0.0)
const GATE_POINT := Vector2(11.5, 0.0)

var _iron_mat: StandardMaterial3D
var _bar_mesh: BoxMesh
var _tip_mesh: CylinderMesh


func _ready() -> void:
	_apply_ground(Build.box(self, Vector3(0, -0.25, 0), Vector3(HALF_X * 2, 0.5, HALF_Z * 2), Color(0.34, 0.26, 0.18), true))

	var moon_light := get_parent().get_node_or_null("Moon") as DirectionalLight3D
	if moon_light:
		moon_light.look_at_from_position(MOON_DIR * 60.0, Vector3.ZERO)

	_iron_mat = StandardMaterial3D.new()
	_iron_mat.albedo_color = IRON
	_bar_mesh = BoxMesh.new()
	_bar_mesh.size = Vector3(0.05, FENCE_H, 0.05)
	_tip_mesh = CylinderMesh.new()
	_tip_mesh.top_radius = 0.0
	_tip_mesh.bottom_radius = 0.05
	_tip_mesh.height = 0.25

	_build_fence()
	_build_collision()

	var gate := Gate.new()
	gate.position = Vector3(HALF_X, 0, 0)
	add_child(gate)

	_build_car()
	_build_world()


func _build_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = StallManager.layout_seed

	var stalls: Array[Node3D] = []
	for node_name in ["StallDart", "StallGoldfish", "StallCork"]:
		stalls.append(get_parent().get_node(node_name))
	var spots := _pick_stall_spots(rng)
	for i in stalls.size():
		stalls[i].position = Vector3(spots[i].x, 0, spots[i].y)

	var segments: Array = []
	segments.append([GATE_POINT, HUB, 2.4])
	for spot in spots:
		segments.append([HUB, spot + Vector2(0, 2.3), 1.8])
	for seg in segments:
		_road(seg[0], seg[1], seg[2])
	for spot in spots:
		Build.box(self, Vector3(spot.x, 0.02, spot.y + 2.0), Vector3(3.6, 0.04, 2.2), ROAD)

	_build_trees(rng, spots, segments)
	_build_grass(rng, spots, segments)


func _pick_stall_spots(rng: RandomNumberGenerator) -> Array[Vector2]:
	for attempt in 500:
		var spots: Array[Vector2] = []
		for i in 3:
			spots.append(Vector2(rng.randf_range(-9.5, 5.0), rng.randf_range(-6.2, 3.0)))
		if _layout_ok(spots):
			return spots
	var row: Array[Vector2] = [Vector2(-8, -4.5), Vector2(-2, -4.5), Vector2(4, 1.5)]
	for i in range(row.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := row[i]
		row[i] = row[j]
		row[j] = tmp
	return row


func _layout_ok(spots: Array[Vector2]) -> bool:
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			var d := (spots[i] - spots[j]).abs()
			if d.x <= 4.4 and d.y <= 4.0:
				return false
		if absf(HUB.x - spots[i].x) < 3.7 and HUB.y > spots[i].y - 3.3 and HUB.y < spots[i].y + 4.7:
			return false
		var front := spots[i] + Vector2(0, 2.3)
		for step in 24:
			var p := HUB.lerp(front, step / 25.0)
			for other in spots:
				if _in_stall_body(p, other, 0.5):
					return false
	return true


func _in_stall_body(p: Vector2, stall: Vector2, margin: float) -> bool:
	return absf(p.x - stall.x) < 1.9 + margin and p.y > stall.y - 1.4 - margin and p.y < stall.y + 1.2 + margin


func _apply_ground(node: Node3D) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ground.gdshader")
	for child in node.get_children():
		if child is MeshInstance3D:
			child.material_override = mat


func _grass_blade_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	for k in 3:
		var a := k * PI / 3.0
		var dx := cos(a) * 0.035
		var dz := sin(a) * 0.035
		var lean := Vector3(cos(a + 1.57), 0, sin(a + 1.57)) * 0.04
		var base := verts.size()
		verts.append(Vector3(-dx, 0, -dz))
		verts.append(Vector3(dx, 0, dz))
		verts.append(Vector3(-dx * 0.5, 0.17, -dz * 0.5) + lean)
		verts.append(Vector3(dx * 0.5, 0.17, dz * 0.5) + lean)
		verts.append(lean * 2.4 + Vector3(0, 0.34, 0))
		uvs.append_array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 0.5), Vector2(1, 0.5), Vector2(0.5, 1)])
		for i in 5:
			normals.append(Vector3.UP)
		idx.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2, base + 2, base + 3, base + 4])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _grass_free(p: Vector2, spots: Array[Vector2], segments: Array) -> bool:
	if p.x > HALF_X - 0.9 and absf(p.y) < 2.2:
		return false
	for spot in spots:
		if absf(p.x - spot.x) < 2.0 and p.y > spot.y - 1.5 and p.y < spot.y + 3.3:
			return false
	for seg in segments:
		if _segment_distance(p, seg[0], seg[1]) < seg[2] / 2.0 + 0.1:
			return false
	return true


func _build_grass(rng: RandomNumberGenerator, spots: Array[Vector2], segments: Array) -> void:
	var transforms: Array[Transform3D] = []
	var colors := PackedColorArray()
	var density := 16.0
	var count := int(HALF_X * 2.0 * HALF_Z * 2.0 * density)
	for i in count:
		var p := Vector2(rng.randf_range(-HALF_X + 0.5, HALF_X - 0.5), rng.randf_range(-HALF_Z + 0.5, HALF_Z - 0.5))
		if not _grass_free(p, spots, segments):
			continue
		var s := rng.randf_range(0.6, 1.6)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.5), s))
		transforms.append(Transform3D(basis, Vector3(p.x, 0.0, p.y)))
		var v := rng.randf_range(0.75, 1.15)
		colors.append(Color(v, v * rng.randf_range(0.95, 1.1), v * 0.9))

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _grass_blade_mesh()
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass.gdshader")
	var inst := MultiMeshInstance3D.new()
	inst.name = "Grass"
	inst.multimesh = mm
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


func _road(a: Vector2, b: Vector2, width: float) -> void:
	var piece := Build.box(self, Vector3((a.x + b.x) / 2.0, 0.02, (a.y + b.y) / 2.0), Vector3(a.distance_to(b), 0.04, width), ROAD)
	piece.rotation.y = -atan2(b.y - a.y, b.x - a.x)


func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _build_trees(rng: RandomNumberGenerator, spots: Array[Vector2], segments: Array) -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.14
	trunk_mesh.bottom_radius = 0.2
	trunk_mesh.height = 2.0
	trunk_mesh.radial_segments = 8
	trunk_mesh.rings = 1
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.28, 0.18, 0.11)
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.08, 0.27, 0.13)
	var meshes: Array[Mesh] = [trunk_mesh]
	var mats: Array[Material] = [trunk_mat]
	for dims in [Vector2(1.3, 1.7), Vector2(1.0, 1.5), Vector2(0.65, 1.3)]:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = dims.x
		cone.height = dims.y
		cone.radial_segments = 10
		cone.rings = 1
		meshes.append(cone)
		mats.append(leaf_mat)

	var ground := Build.box(self, Vector3(0, -0.3, 0), Vector3(90, 0.5, 80), Color(0.1, 0.2, 0.1))
	_apply_ground(ground)
	ground.name = "OuterGround"

	# transforms[solid][part]: inner trees cast shadows and block the player; the outer forest is scenery only.
	var transforms := {true: [[], [], [], []], false: [[], [], [], []]}
	var pine := _load_pine()
	var pine_spots := {true: [] as Array[Transform3D], false: [] as Array[Transform3D]}

	var cell := 2.6
	var x := -HALF_X + 1.2
	while x < HALF_X - 1.0:
		var z := -HALF_Z + 1.2
		while z < HALF_Z - 1.0:
			var p := Vector2(x + rng.randf_range(-0.8, 0.8), z + rng.randf_range(-0.8, 0.8))
			var keep := rng.randf() < 0.75
			if keep and _tree_spot_free(p, spots, segments):
				var s := rng.randf_range(0.8, 1.5)
				if pine.is_empty():
					_tree(p, s, meshes, transforms[true], true)
				else:
					_pine_tree(p, s * 0.55, rng.randf() * TAU, pine_spots[true], true)
			z += cell
		x += cell

	var outer := 3.4
	x = -28.0
	while x < 28.0:
		var z := -24.0
		while z < 24.0:
			var p := Vector2(x + rng.randf_range(-1.2, 1.2), z + rng.randf_range(-1.2, 1.2))
			var inside_fence := absf(p.x) < HALF_X + 1.8 and absf(p.y) < HALF_Z + 1.8
			var gate_lane := p.x > 0.0 and absf(p.y) < 5.0
			var near_road := p.x > ROAD_X - ROAD_W / 2.0 - 4.0
			if not inside_fence and not gate_lane and rng.randf() < 0.8:
				var s := rng.randf_range(1.0, 2.0)
				if pine.is_empty():
					_tree(p, s, meshes, transforms[false], false)
				elif not near_road:
					_pine_tree(p, s * 0.7, rng.randf() * TAU, pine_spots[false], false)
			z += outer
		x += outer

	if not pine.is_empty():
		for solid in [true, false]:
			var list: Array[Transform3D] = pine_spots[solid]
			if list.is_empty():
				continue
			for part in pine["parts"]:
				var inst := _scatter(part[0], null, list, Vector3.ZERO, [], part[1])
				if not solid:
					inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return

	for solid in [true, false]:
		for part in meshes.size():
			var list: Array = transforms[solid][part]
			if list.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = meshes[part]
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i])
			var inst := MultiMeshInstance3D.new()
			inst.multimesh = mm
			inst.material_override = mats[part]
			if not solid:
				inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(inst)


func _tree_spot_free(p: Vector2, spots: Array[Vector2], segments: Array) -> bool:
	if p.x > 8.3 and absf(p.y) < 3.5:
		return false
	if absf(p.x) < 3.6 and p.y > HALF_Z - 3.2:
		return false
	for spot in spots:
		if absf(p.x - spot.x) < 3.1 and p.y > spot.y - 2.6 and p.y < spot.y + 4.2:
			return false
	for seg in segments:
		if _segment_distance(p, seg[0], seg[1]) < seg[2] / 2.0 + 1.1:
			return false
	return true


func _pine_tree(p: Vector2, scale_factor: float, yaw: float, out: Array[Transform3D], solid: bool) -> void:
	out.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_factor), Vector3(p.x, 0, p.y)))
	if solid:
		var body := StaticBody3D.new()
		body.position = Vector3(p.x, 0, p.y)
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.3
		cyl.height = 2.0
		shape.shape = cyl
		shape.position.y = 1.0
		body.add_child(shape)
		add_child(body)


func _tree(p: Vector2, scale_factor: float, meshes: Array[Mesh], out: Array, solid: bool) -> void:
	var base := Transform3D(Basis.from_scale(Vector3.ONE * scale_factor), Vector3(p.x, 0, p.y))
	out[0].append(base * Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 0)))
	var y := 1.6
	for i in range(1, meshes.size()):
		var h: float = (meshes[i] as CylinderMesh).height
		out[i].append(base * Transform3D(Basis.IDENTITY, Vector3(0, y + h / 2.0, 0)))
		y += h * 0.6

	if solid:
		var body := StaticBody3D.new()
		body.position = Vector3(p.x, 0, p.y)
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.3
		cyl.height = 2.0
		shape.shape = cyl
		shape.position.y = 1.0
		body.add_child(shape)
		add_child(body)


func _build_fence() -> void:
	var gate_edge := Gate.OPENING_HALF + Gate.PILLAR
	_fence_run(Vector3(-HALF_X, 0, -HALF_Z), Vector3(HALF_X, 0, -HALF_Z))
	_fence_run(Vector3(-HALF_X, 0, HALF_Z), Vector3(HALF_X, 0, HALF_Z))
	_fence_run(Vector3(-HALF_X, 0, -HALF_Z), Vector3(-HALF_X, 0, HALF_Z))
	_fence_run(Vector3(HALF_X, 0, -HALF_Z), Vector3(HALF_X, 0, -gate_edge))
	_fence_run(Vector3(HALF_X, 0, gate_edge), Vector3(HALF_X, 0, HALF_Z))

	for x in [-6.0, 0.0, 6.0]:
		_post(x, -HALF_Z)
		_post(x, HALF_Z)
	for z in [-4.5, 0.0, 4.5]:
		_post(-HALF_X, z)
	for z in [-6.0, 6.0]:
		_post(HALF_X, z)
	for cx in [-HALF_X, HALF_X]:
		for cz in [-HALF_Z, HALF_Z]:
			_post(cx, cz)
			_torch(cx, cz)


func _fence_run(a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	var along_x := absf(b.x - a.x) > absf(b.z - a.z)
	var count := int(length / BAR_SPACING) + 1
	var bars: Array[Transform3D] = []
	var tips: Array[Transform3D] = []
	for i in count:
		var p := a.lerp(b, float(i) / maxf(count - 1, 1))
		bars.append(Transform3D(Basis.IDENTITY, p + Vector3(0, FENCE_H / 2.0, 0)))
		tips.append(Transform3D(Basis.IDENTITY, p + Vector3(0, FENCE_H + 0.12, 0)))
	_spawn_multimesh(_bar_mesh, bars)
	_spawn_multimesh(_tip_mesh, tips)

	var mid := (a + b) / 2.0
	var rail_size := Vector3(length, 0.08, 0.08) if along_x else Vector3(0.08, 0.08, length)
	Build.box(self, mid + Vector3(0, 0.4, 0), rail_size, IRON)
	Build.box(self, mid + Vector3(0, FENCE_H - 0.35, 0), rail_size, IRON)


func _spawn_multimesh(mesh: Mesh, transforms: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = _iron_mat
	add_child(inst)


func _post(x: float, z: float) -> void:
	Build.box(self, Vector3(x, (FENCE_H + 0.5) / 2.0, z), Vector3(0.5, FENCE_H + 0.5, 0.5), STONE)
	Build.box(self, Vector3(x, FENCE_H + 0.6, z), Vector3(0.65, 0.2, 0.65), STONE)


func _torch(x: float, z: float) -> void:
	Build.lantern(self, Vector3(x, FENCE_H + 0.95, z), Color(1.0, 0.55, 0.2))
	var light := OmniLight3D.new()
	light.position = Vector3(x - signf(x) * 0.8, FENCE_H + 0.9, z - signf(z) * 0.8)
	light.light_color = Color(1.0, 0.65, 0.35)
	light.light_energy = 1.2
	light.omni_range = 9.0
	add_child(light)


# The fence is solid: invisible collision walls on every side, with a gap only where the gate stands.
func _build_collision() -> void:
	var seg := HALF_Z - Gate.OPENING_HALF
	var center := Gate.OPENING_HALF + seg / 2.0
	Build.invisible_wall(self, Vector3(0, WALL_H / 2, -HALF_Z), Vector3(HALF_X * 2 + 1, WALL_H, 1))
	Build.invisible_wall(self, Vector3(0, WALL_H / 2, HALF_Z), Vector3(HALF_X * 2 + 1, WALL_H, 1))
	Build.invisible_wall(self, Vector3(-HALF_X, WALL_H / 2, 0), Vector3(1, WALL_H, HALF_Z * 2 + 1))
	Build.invisible_wall(self, Vector3(HALF_X, WALL_H / 2, -center), Vector3(1, WALL_H, seg))
	Build.invisible_wall(self, Vector3(HALF_X, WALL_H / 2, center), Vector3(1, WALL_H, seg))


func _build_car() -> void:
	var car := CarModel.make()
	car.name = "EscapeCar"
	car.position = Vector3(CAR_POS.x, 0.0, CAR_POS.y)
	car.rotation.y = PI
	add_child(car)
	CarModel.add_headlights(car, false)
	_build_outside()


# Dirt ground, a road running north-south past the gate, and a dense pine forest around it.
func _build_outside() -> void:
	var flies := Fireflies.new()
	flies.name = "Fireflies"
	add_child(flies)
	var grass := Color(0.05, 0.085, 0.045)
	Build.box(self, Vector3(77.0, -0.27, 0), Vector3(130.0, 0.5, 340.0), grass, false)
	Build.box(self, Vector3(ROAD_X, -0.24, 0), Vector3(ROAD_W, 0.5, 340.0), Color(0.12, 0.12, 0.14), false)
	for i in 68:
		Build.box(self, Vector3(ROAD_X, 0.015, -165.0 + i * 5.0), Vector3(0.14, 0.02, 2.2), Color(0.75, 0.68, 0.38), false, 0.2)
	for side in [-1.0, 1.0]:
		Build.box(self, Vector3(ROAD_X + side * (ROAD_W / 2.0 + 0.08), 0.0, 0), Vector3(0.12, 0.02, 340.0), Color(0.55, 0.52, 0.45), false)

	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var pine := _load_pine()
	var spots: Array[Transform3D] = []
	var spot_colors: Array[Color] = []
	var tries := 0
	var tree_count := FOREST_TREES if pine.is_empty() else FOREST_PINES
	while spots.size() < tree_count and tries < tree_count * 8:
		tries += 1
		var p := Vector2(rng.randf_range(13.5, 135.0), rng.randf_range(-160.0, 160.0))
		var tall := rng.randf_range(0.8, 1.9) if pine.is_empty() else rng.randf_range(0.8, 1.4)
		var canopy: float = 1.5 * tall if pine.is_empty() else pine["radius"] * tall
		if absf(p.x - ROAD_X) < ROAD_W / 2.0 + canopy + 1.2:
			continue
		if p.x < 31.0 and absf(p.y) < 17.0:
			continue
		var too_close := false
		for s in spots:
			if Vector2(s.origin.x, s.origin.z).distance_to(p) < 1.6:
				too_close = true
				break
		if too_close:
			continue
		var tree_basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * tall)
		spots.append(Transform3D(tree_basis, Vector3(p.x, 0.0, p.y)))
		var shade := rng.randf_range(0.7, 1.25)
		spot_colors.append(Color(0.04 * shade, 0.13 * shade, 0.07 * shade))

	if not pine.is_empty():
		for part in pine["parts"]:
			_scatter(part[0], null, spots, Vector3.ZERO, [], part[1])
	else:
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.16
		trunk.bottom_radius = 0.26
		trunk.height = 2.2
		var trunk_mat := StandardMaterial3D.new()
		trunk_mat.albedo_color = Color(0.14, 0.09, 0.06)
		_scatter(trunk, trunk_mat, spots, Vector3(0, 1.1, 0), [])
		var leaf_mat := StandardMaterial3D.new()
		leaf_mat.vertex_color_use_as_albedo = true
		for k in 4:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 1.6 - k * 0.36
			cone.height = 1.9
			_scatter(cone, leaf_mat, spots, Vector3(0, 2.0 + k * 0.95, 0), spot_colors)

	var bush := SphereMesh.new()
	bush.radius = 0.6
	bush.height = 0.9
	var bush_mat := StandardMaterial3D.new()
	bush_mat.vertex_color_use_as_albedo = true
	var bushes: Array[Transform3D] = []
	var bush_colors: Array[Color] = []
	var attempts := 0
	while bushes.size() < FOREST_BUSHES and attempts < FOREST_BUSHES * 6:
		attempts += 1
		var q := Vector2(rng.randf_range(13.5, 135.0), rng.randf_range(-160.0, 160.0))
		if absf(q.x - ROAD_X) < ROAD_W / 2.0 + 1.0 or (q.x < 31.0 and absf(q.y) < 17.0):
			continue
		var sz := rng.randf_range(0.6, 1.4)
		bushes.append(Transform3D(Basis.IDENTITY.scaled(Vector3(sz * 1.3, sz, sz * 1.3)), Vector3(q.x, 0.25 * sz, q.y)))
		bush_colors.append(Color(0.04, rng.randf_range(0.1, 0.17), 0.05))
	_scatter(bush, bush_mat, bushes, Vector3.ZERO, bush_colors)


func _scatter(mesh: Mesh, mat: Material, spots: Array[Transform3D], local: Vector3, colors: Array, part := Transform3D.IDENTITY) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = spots.size()
	for i in spots.size():
		var xf := spots[i] * part
		xf.origin += xf.basis * local
		mm.set_instance_transform(i, xf)
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	if mat:
		inst.material_override = mat
	add_child(inst)
	return inst


# Collects the pine's meshes with transforms that stand it on y = 0, centred, PINE_HEIGHT tall.
func _load_pine() -> Dictionary:
	if not ResourceLoader.exists(PINE_PATH):
		return {}
	var scene = load(PINE_PATH)
	if not scene is PackedScene:
		return {}
	var root: Node3D = scene.instantiate()
	var parts: Array = []
	_collect_meshes(root, Transform3D.IDENTITY, parts)
	root.free()
	if parts.is_empty():
		return {}
	var bb := AABB()
	for i in parts.size():
		var b: AABB = parts[i][1] * parts[i][0].get_aabb()
		bb = b if i == 0 else bb.merge(b)
	var s := PINE_HEIGHT / maxf(bb.size.y, 0.001)
	var c := bb.get_center()
	var fix := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3(-c.x * s, -bb.position.y * s, -c.z * s))
	for part in parts:
		part[1] = fix * part[1]
	return {"parts": parts, "radius": maxf(bb.size.x, bb.size.z) * 0.5 * s * 0.8}


func _collect_meshes(node: Node, xf: Transform3D, out: Array) -> void:
	if node is MeshInstance3D and node.mesh:
		out.append([node.mesh, xf])
	for child in node.get_children():
		if child is Node3D:
			_collect_meshes(child, xf * child.transform, out)
