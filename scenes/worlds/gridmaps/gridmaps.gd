extends Node3D


@export var mesh_library : MeshLibrary

var data : WorldData

@onready var gridmaps = {
	"ground" : $ground,
	"wall_xp" : $wall_xp,
	"wall_xn" : $wall_xn,
	"wall_zp" : $wall_zp,
	"wall_zn" : $wall_zn,
	"pillar" : $pillar,
	"ceiling" : $ceiling,
}


func update_gridmaps():
	for slot in gridmaps.keys():
		(gridmaps[slot] as GridMap).cell_size = Vector3(WorldData.CELL_SIZE, WorldData.WALL_SIZE, WorldData.CELL_SIZE)
		(gridmaps[slot] as GridMap).cell_center_x = true
		(gridmaps[slot] as GridMap).cell_center_y = false
		(gridmaps[slot] as GridMap).cell_center_z = true
		(gridmaps[slot] as GridMap).clear()
		(gridmaps[slot] as GridMap).mesh_library = mesh_library
	var zn_transform = Transform3D.IDENTITY
	var xn_transform = zn_transform.rotated(Vector3.UP, PI*0.5)
	var zp_transform = zn_transform.rotated(Vector3.UP, PI*1.0)
	var xp_transform = zn_transform.rotated(Vector3.UP, PI*1.5)
	var zn = gridmaps.ground.get_orthogonal_index_from_basis(zn_transform.basis)
	var xp = gridmaps.ground.get_orthogonal_index_from_basis(xp_transform.basis)
	var zp = gridmaps.ground.get_orthogonal_index_from_basis(zp_transform.basis)
	var xn = gridmaps.ground.get_orthogonal_index_from_basis(xn_transform.basis)
	for i in data.cell_count:
		var coords = data.get_int_position_from_cell_index(i)
		(gridmaps.ground as GridMap).set_cell_item(Vector3(coords[0], 0, coords[1]), data.get_ground_tile_index(i))
		(gridmaps.wall_xn as GridMap).set_cell_item(Vector3(coords[0], 0, coords[1]), data.get_wall_tile_index(i, data.Direction.WEST), xn)
		(gridmaps.wall_xp as GridMap).set_cell_item(Vector3(coords[0], 0, coords[1]), data.get_wall_tile_index(i, data.Direction.EAST), xp)
		(gridmaps.wall_zn as GridMap).set_cell_item(Vector3(coords[0], 0, coords[1]), data.get_wall_tile_index(i, data.Direction.NORTH), zn)
		(gridmaps.wall_zp as GridMap).set_cell_item(Vector3(coords[0], 0, coords[1]), data.get_wall_tile_index(i, data.Direction.SOUTH), zp)
		(gridmaps.ceiling as GridMap).set_cell_item(Vector3(coords[0], 0, coords[1]), data.get_ceiling_tile_index(i))
		(gridmaps.pillar as GridMap).set_cell_item(Vector3(coords[0], 0, coords[1]), data.get_pillar_tile_index(i))
