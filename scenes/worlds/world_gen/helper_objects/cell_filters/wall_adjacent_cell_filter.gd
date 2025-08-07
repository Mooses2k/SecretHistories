class_name WallAdjacentCellFilter
extends CellFilter

## Simple wall-adjacent placement for small objects
## Used for basic "place next to wall" scenarios


func filter_cells(world_data: WorldData, room_data: RoomData, rng: RandomNumberGenerator = null) -> Array:
	if not room_data:
		return []
	
	# Get all room cells, then filter for wall-adjacent ones using base class utility
	var room_cells := room_data.cell_indexes
	var available_cells := filter_available_cells(world_data, room_cells)
	var wall_adjacent_cells := filter_cells_adjacent_to_walls(world_data, available_cells)
	
	return wall_adjacent_cells