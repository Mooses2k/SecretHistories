class_name SequentialCellFilter
extends CellFilter

## Finds next available cell sequentially
## Consolidates logic from item_spawner.gd:75-82

var max_count: int = 1
var _current_cell: int = 0


func filter_cells(world_data: WorldData, room_data: RoomData, rng: RandomNumberGenerator = null) -> Array:
	var candidate_cells := []
	var count := 0
	
	while count < max_count and _get_next_free_cell(world_data):
		candidate_cells.append(_current_cell)
		count += 1
	
	return candidate_cells


func _get_next_free_cell(world_data: WorldData) -> bool:
	_current_cell += 1
	# Use base class utility for cell type checking
	while (_current_cell < world_data.cell_count 
			and get_cell_type(world_data, _current_cell) == WorldData.CellType.EMPTY):
		_current_cell += 1
	
	return _current_cell < world_data.cell_count


func reset():
	_current_cell = 0


func set_max_count(count: int) -> SequentialCellFilter:
	max_count = count
	return self