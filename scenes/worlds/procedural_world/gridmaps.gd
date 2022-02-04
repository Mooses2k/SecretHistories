extends Navigation

enum CornerTypes {
	FREE,
	X, #side
	Z, #side
	XZ, #corner
	X_Z, #both sides
	COUNT,
}

export var nav_margin = 0.5
export var navigation_visible = true
export var navigation_debug_material : Material

onready var world : GameWorld = get_parent() as GameWorld
onready var floor_map : GridMap = $Floor as GridMap
onready var wallx_plus_map : GridMap = $WallsXp as GridMap
onready var wallx_minus_map : GridMap = $WallsXn as GridMap
onready var wallz_plus_map : GridMap = $WallsZp as GridMap
onready var wallz_minus_map : GridMap = $WallsZn as GridMap

# Make this an array later
var floor_index = 1
var wall_index = 4

#plus and minus refers to facing, not position
var wallx_plus_basis : Basis = Basis.IDENTITY.rotated(Vector3.UP, deg2rad(90))
var wallx_minus_basis : Basis = Basis.IDENTITY.rotated(Vector3.UP, deg2rad(270))
var wallz_plus_basis : Basis = Basis.IDENTITY
var wallz_minus_basis : Basis = Basis.IDENTITY.rotated(Vector3.UP, deg2rad(180))

var corner_navmeshes = Array()
var corner_meshes_debug = Array()

#for debug
var multimeshes = Array()
var instances = Array()
var visible_instances = Array()

func _ready():
	initialize_corner_navmeshes()
	multimeshes.resize(CornerTypes.COUNT)
	visible_instances.resize(CornerTypes.COUNT)
	for i in CornerTypes.COUNT:
#		print((corner_navmeshes[i] as NavigationMesh).get_polygon_count())
		multimeshes[i] = VisualServer.multimesh_create()
		VisualServer.multimesh_set_mesh(multimeshes[i], (corner_meshes_debug[i] as ArrayMesh).get_rid())
		visible_instances[i] = 0

	instances.resize(CornerTypes.COUNT)
	for i in CornerTypes.COUNT:
		instances[i] = VisualServer.instance_create2(multimeshes[i], get_world().scenario)
		VisualServer.instance_set_visible(instances[i], navigation_visible)
		VisualServer.instance_geometry_set_material_override(instances[i], navigation_debug_material.get_rid())

func initialize_corner_navmeshes():
	corner_navmeshes.resize(CornerTypes.COUNT)
	corner_meshes_debug.resize(CornerTypes.COUNT)
	for i in CornerTypes.COUNT:
		var vertices
		var indices
		match i:
			CornerTypes.FREE:
				vertices = PoolVector3Array([
					Vector3(0, 0, 0),
					Vector3(1, 0, 0),
					Vector3(1, 0, 1),
					Vector3(0, 0, 1),
				])
				indices = PoolIntArray([
					0, 1, 2,
					0, 2, 3
				])
			CornerTypes.X:
				vertices = PoolVector3Array([
					Vector3(0, 0, 0),
					Vector3(1 - nav_margin, 0, 0),
					Vector3(1 - nav_margin, 0, 1),
					Vector3(0, 0, 1),
				])
				indices = PoolIntArray([
					0, 1, 2,
					0, 2, 3
				])
			CornerTypes.Z:
				vertices = PoolVector3Array([
					Vector3(0, 0, 0),
					Vector3(1, 0, 0),
					Vector3(1, 0, 1 - nav_margin),
					Vector3(0, 0, 1 - nav_margin),
				])
				indices = PoolIntArray([
					0, 1, 2,
					0, 2, 3
				])
			CornerTypes.XZ:
				vertices = PoolVector3Array([
					Vector3(0, 0, 0),
					Vector3(1 - nav_margin, 0, 0),
					Vector3(1 - nav_margin, 0, 1 - nav_margin),
					Vector3(0, 0, 1 - nav_margin),

					Vector3(1 - nav_margin, 0, 0),
					Vector3(1, 0, 0),
					Vector3(1, 0, 1 - nav_margin),
					Vector3(1 - nav_margin, 0, 1 - nav_margin),


					Vector3(0, 0, 1 - nav_margin),
					Vector3(1 - nav_margin, 0, 1 - nav_margin),
					Vector3(1 - nav_margin, 0, 1),
					Vector3(0, 0, 1),
				])
				indices = PoolIntArray([
					0, 1, 2,
					0, 2, 3,
					4, 5, 6,
					4, 6, 7,
					8, 9, 10,
					8, 10, 11,
				])
			CornerTypes.X_Z:
				vertices = PoolVector3Array([
					Vector3(0, 0, 0),
					Vector3(1 - nav_margin, 0, 0),
					Vector3(1 - nav_margin, 0, 1 - nav_margin),
					Vector3(0, 0, 1 - nav_margin),
				])
				indices = PoolIntArray([
					0, 1, 2,
					0, 2, 3
				])
		var array_mesh = ArrayMesh.new()
		var arrays = Array()
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_INDEX] = indices
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var nav_mesh = NavigationMesh.new()
		nav_mesh.create_from_mesh(array_mesh)
		corner_navmeshes[i] = nav_mesh
		corner_meshes_debug[i] = array_mesh

func populate_grid(world_data : Array, world_size : int):
	for i in world_size:
		for j in world_size:
			if world_data[i][j] == true:
				floor_map.set_cell_item(i, 0, j, floor_index)
				if i - 1 < 0 or world_data[i - 1][j] == false:
					wallx_plus_map.set_cell_item(i, 0, j, wall_index, wallx_plus_basis.get_orthogonal_index())
				if i + 1 > world_size - 1 or world_data[i + 1][j] == false:
					wallx_minus_map.set_cell_item(i, 0, j, wall_index, wallx_minus_basis.get_orthogonal_index())
				if j - 1 < 0 or world_data[i][j - 1] == false:
					wallz_plus_map.set_cell_item(i, 0, j, wall_index, wallz_plus_basis.get_orthogonal_index())
				if j + 1 > world_size - 1 or world_data[i][j + 1] == false:
					wallz_minus_map.set_cell_item(i, 0, j, wall_index, wallz_minus_basis.get_orthogonal_index())

func generate_navmesh(world_data : Array, world_size : int):
	for i in CornerTypes.COUNT:
		VisualServer.multimesh_allocate(multimeshes[i], world_size*world_size, VisualServer.MULTIMESH_TRANSFORM_3D, VisualServer.MULTIMESH_COLOR_NONE, VisualServer.MULTIMESH_CUSTOM_DATA_NONE)
	for i in world_size:
		for j in world_size:
			if world_data[i][j]:
				var offset_matrix = Transform.IDENTITY.translated(world.grid_to_world(Vector3(i, 0, j)))
				var rotation_scale_matrix : Transform = Transform.IDENTITY.scaled(Vector3.ONE*world.CELL_SIZE*0.5)
				var x_coords = [[i + 1, j], [i, j + 1], [i - 1, j], [i, j - 1]]
				var z_coords = [[i, j + 1], [i - 1, j], [i, j - 1], [i + 1, j]]
				var xz_coords = [[i + 1, j + 1], [i - 1, j + 1], [i - 1, j - 1], [i + 1, j - 1]]

				for k in 4:
					var x_blocked = true
					if (x_coords[k][0] >= 0 and x_coords[k][0] < world_size and x_coords[k][1] >= 0 and x_coords[k][1] < world_size):
						x_blocked = not world_data[x_coords[k][0]][x_coords[k][1]]
					var z_blocked = true
					if (z_coords[k][0] >= 0 and z_coords[k][0] < world_size and z_coords[k][1] >= 0 and z_coords[k][1] < world_size):
						z_blocked = not world_data[z_coords[k][0]][z_coords[k][1]]
					var xz_blocked = true
					if (xz_coords[k][0] >= 0 and xz_coords[k][0] < world_size and xz_coords[k][1] >= 0 and xz_coords[k][1] < world_size):
						xz_blocked = not world_data[xz_coords[k][0]][xz_coords[k][1]]

					var selected = CornerTypes.FREE
					if x_blocked and not z_blocked:
						selected = CornerTypes.X
					elif z_blocked and not x_blocked:
						selected = CornerTypes.Z
					elif x_blocked and z_blocked:
						selected = CornerTypes.X_Z
					elif xz_blocked:
						selected = CornerTypes.XZ
					navmesh_add(corner_navmeshes[selected], offset_matrix*rotation_scale_matrix)
					VisualServer.multimesh_instance_set_transform(multimeshes[selected], visible_instances[selected], offset_matrix*rotation_scale_matrix)
					visible_instances[selected] += 1
					rotation_scale_matrix = rotation_scale_matrix.rotated(Vector3.UP, -0.5*PI)
	for i in CornerTypes.COUNT:
		VisualServer.multimesh_set_visible_instances(multimeshes[i], visible_instances[i])

func _on_World_world_data_changed(new_data, new_size):
	populate_grid(new_data, new_size)
	generate_navmesh(new_data, new_size)
	pass # Replace with function body.
