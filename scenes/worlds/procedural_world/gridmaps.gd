extends Navigation

onready var floor_map : GridMap = $Floor as GridMap
onready var wallx_map : GridMap = $WallsX as GridMap
onready var wallz_map : GridMap = $WallsZ as GridMap

# Make this an array later
var floor_index = 4
var wall_index = 3
var wallx_basis : Basis = Basis.IDENTITY.rotated(Vector3.UP, deg2rad(90))

func generate_mesh(world_data : Array, world_size : int):
	for i in world_size:
		for j in world_size:
			if world_data[i][j] == true:
				floor_map.set_cell_item(i, 0, j, floor_index)
				if i - 1 < 0 or world_data[i - 1][j] == false:
					wallx_map.set_cell_item(i, 0, j, wall_index, wallx_basis.get_orthogonal_index())
				if i + 1 > world_size - 1 or world_data[i + 1][j] == false:
					wallx_map.set_cell_item(i + 1, 0, j, wall_index, wallx_basis.get_orthogonal_index())
				if j - 1 < 0 or world_data[i][j - 1] == false:
					wallz_map.set_cell_item(i, 0, j, wall_index)
				if j + 1 > world_size - 1 or world_data[i][j + 1] == false:
					wallz_map.set_cell_item(i, 0, j + 1, wall_index)
