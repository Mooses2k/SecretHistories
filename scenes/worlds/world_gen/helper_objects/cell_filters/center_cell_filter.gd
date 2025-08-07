class_name CenterCellFilter
extends CellFilter

## Filters for center cells of rooms for large objects
## Works independently or with WallSegmentCellFilter for proper space calculation


var object_size: Vector2 = Vector2.ONE
var walls_data: WallSegmentCellFilter = null  # Optional - for rooms with wall objects


func filter_cells(world_data: WorldData, room_data: RoomData, rng: RandomNumberGenerator = null) -> Array:
	if not room_data:
		return []
	
	# Calculate remaining space after accounting for wall objects (if any)
	var remaining_rect: Rect2
	if walls_data:
		# Use wall data to calculate remaining space
		remaining_rect = walls_data.get_remaining_rect(room_data)
	else:
		# Work independently - use full room minus basic wall clearance
		remaining_rect = _calculate_independent_remaining_rect(room_data)
	
	# Check if object can fit in remaining space
	if not _can_place_object(remaining_rect):
		return []
	
	# Calculate center position
	var placement_data := _calculate_center_position(remaining_rect, world_data.CELL_SIZE)
	
	# Get center cells
	var center_cells := _get_center_cells(world_data, placement_data.rect)
	
	return center_cells


## Set wall data for proper space calculation when used with WallSegmentCellFilter
func set_walls_data(wall_filter: WallSegmentCellFilter) -> CenterCellFilter:
	walls_data = wall_filter
	return self


func set_object_size(size: Vector2) -> CenterCellFilter:
	object_size = size
	return self


## Get placement data for center object (position and offset)
func get_center_placement_data(world_data: WorldData, room_data: RoomData) -> Dictionary:
	var remaining_rect: Rect2
	if walls_data:
		remaining_rect = walls_data.get_remaining_rect(room_data)
	else:
		remaining_rect = _calculate_independent_remaining_rect(room_data)
	
	if not _can_place_object(remaining_rect):
		return {}
	
	var placement_data := _calculate_center_position(remaining_rect, world_data.CELL_SIZE)
	var center_cells := _get_center_cells(world_data, placement_data.rect)
	
	if center_cells.is_empty():
		return {}
	
	return {
		"cells": center_cells,
		"offset": placement_data.offset,
		"rect": placement_data.rect
	}


### Private Methods -------------------------------------------------------------------------------

## Calculate remaining rect when working independently (no wall objects)
func _calculate_independent_remaining_rect(room_data: RoomData) -> Rect2:
	var room_rect := room_data.rect2
	# Leave basic clearance from walls (1 cell on each side)
	return Rect2(
		room_rect.position.x + 1,
		room_rect.position.y + 1,
		room_rect.size.x - 2,
		room_rect.size.y - 2
	)


## Check if object can fit
func _can_place_object(remaining_rect: Rect2) -> bool:
	return remaining_rect.size >= object_size


## Calculate center position
func _calculate_center_position(remaining_rect: Rect2, cell_size: float) -> Dictionary:
	var object_rect := Rect2(Vector2.ZERO, object_size)
	object_rect.position = remaining_rect.position
	object_rect.position += remaining_rect.size / 2.0 - object_rect.size / 2.0

	var offset := Vector3(
		object_rect.size.x / 2.0 * cell_size,
		0,
		object_rect.size.y / 2.0 * cell_size
	)

	# Handle fractional positions - floor the position but don't expand rect for center placement
	if snappedf(object_rect.position.x, 1.0) != object_rect.position.x:
		object_rect.position.x = floor(object_rect.position.x)

	if snappedf(object_rect.position.y, 1.0) != object_rect.position.y:
		object_rect.position.y = floor(object_rect.position.y)

	return {
		"rect": object_rect,
		"offset": offset
	}


## Get center cells
func _get_center_cells(world_data: WorldData, placement_rect: Rect2) -> Array:
	var center_cells := []

	for offset_x in placement_rect.size.x:
		var x := (placement_rect.position.x + offset_x) as float
		for offset_y in placement_rect.size.y:
			var y := (placement_rect.position.y + offset_y) as float
			var cell_index := world_data.get_cell_index_from_int_position(x, y)
			center_cells.append(cell_index)
			if not world_data.is_cell_free(cell_index):
				center_cells.clear()
				return center_cells

	return center_cells
