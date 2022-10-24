extends Spatial


var data : Resource setget set_data


func set_data(value : WorldData):
	data = value


export var mesh_library : MeshLibrary

onready var gridmaps = {
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
	var _data = data as WorldData
	var zn_transform = Transform.IDENTITY
	var xn_transform = zn_transform.rotated(Vector3.UP, PI*0.5)
	var zp_transform = zn_transform.rotated(Vector3.UP, PI*1.0)
	var xp_transform = zn_transform.rotated(Vector3.UP, PI*1.5)
	var zn = zn_transform.basis.get_orthogonal_index()
	var xp = xp_transform.basis.get_orthogonal_index()
	var zp = zp_transform.basis.get_orthogonal_index()
	var xn = xn_transform.basis.get_orthogonal_index()
	for i in data.cell_count:
		var coords = _data.get_int_position_from_cell_index(i)
		(gridmaps.ground as GridMap).set_cell_item(coords[0], 0, coords[1], _data.ground_tile_index[i])
		(gridmaps.wall_xn as GridMap).set_cell_item(coords[0], 0, coords[1], _data.wall_tile_index_xn[i], xn)
		(gridmaps.wall_xp as GridMap).set_cell_item(coords[0], 0, coords[1], _data.wall_tile_index_xp[i], xp)
		(gridmaps.wall_zn as GridMap).set_cell_item(coords[0], 0, coords[1], _data.wall_tile_index_zn[i], zn)
		(gridmaps.wall_zp as GridMap).set_cell_item(coords[0], 0, coords[1], _data.wall_tile_index_zp[i], zp)
		(gridmaps.ceiling as GridMap).set_cell_item(coords[0], 0, coords[1], _data.ceiling_tile_index[i])
	for x in data.world_size_x:
		for z in data.world_size_z:
			var i = data.get_pillar_index_from_int_position(x, z)
			(gridmaps.pillar as GridMap).set_cell_item(x, 0, z, _data.pillar_tile_index[i])
	pass
