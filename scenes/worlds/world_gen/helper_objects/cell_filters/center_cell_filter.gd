class_name CenterCellFilter
extends CellFilter

## Filters for center cells of rooms for large objects
## Consolidates logic from generate_sarcophagus.gd and generate_statue_fountain.gd

var object_size: Vector2 = Vector2.ONE


func filter_cells(world_data: WorldData, room_data: RoomData, rng: RandomNumberGenerator = null) -> Array:
	if not room_data:
		return []
	
	# Calculate center area of room
	var room_rect := room_data.rect2
	var center_x := room_rect.position.x + room_rect.size.x / 2
	var center_y := room_rect.position.y + room_rect.size.y / 2
	
	# For multi-tile objects, get the area they would occupy
	var start_x := center_x - object_size.x / 2
	var start_y := center_y - object_size.y / 2
	var center_rect := Rect2(start_x, start_y, object_size.x, object_size.y)
	
	# Get cells in center area using base class utility
	var center_cells := get_cells_in_rect(world_data, center_rect)
	
	# Filter for available cells using base class utility
	var available_cells := filter_available_cells(world_data, center_cells)
	
	# For multi-tile objects, all cells must be available
	if object_size.x > 1 or object_size.y > 1:
		if available_cells.size() != center_cells.size():
			return []  # Not all cells are available
	
	return available_cells


func set_object_size(size: Vector2) -> CenterCellFilter:
	object_size = size
	return self