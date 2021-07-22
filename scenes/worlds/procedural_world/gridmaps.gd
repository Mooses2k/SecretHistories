extends Navigation

onready var floor_map : GridMap = $Floor as GridMap
onready var wallx_plus_map : GridMap = $WallsXp as GridMap
onready var wallx_minus_map : GridMap = $WallsXn as GridMap
onready var wallz_plus_map : GridMap = $WallsZp as GridMap
onready var wallz_minus_map : GridMap = $WallsZn as GridMap

# Make this an array later
var floor_index = 4
var wall_index = 3

#plus and minus refers to facing, not position
var wallx_plus_basis : Basis = Basis.IDENTITY.rotated(Vector3.UP, deg2rad(90))
var wallx_minus_basis : Basis = Basis.IDENTITY.rotated(Vector3.UP, deg2rad(270))
var wallz_plus_basis : Basis = Basis.IDENTITY
var wallz_minus_basis : Basis = Basis.IDENTITY.rotated(Vector3.UP, deg2rad(180))

func generate_mesh(world_data : Array, world_size : int):
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
