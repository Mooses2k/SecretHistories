class_name CellTypeFilter
extends CellFilter

## Filters cells based on cell type (ROOM, CORRIDOR, HALL)
## Consolidates logic from generate_cultists.gd:84-91

var target_cell_types: Array = [WorldData.CellType.ROOM]


func filter_cells(world_data: WorldData, room_data: RoomData, rng: RandomNumberGenerator = null) -> Array:
	var valid_cells := []
	
	# Get cells for each target type using base class utility
	for cell_type in target_cell_types:
		valid_cells.append_array(get_cells_for_type(world_data, cell_type))
	
	valid_cells.sort()
	
	# Remove used cells using base class utility
	valid_cells = remove_used_cells(world_data, valid_cells)
	
	return valid_cells


func set_target_types(types: Array) -> CellTypeFilter:
	target_cell_types = types
	return self