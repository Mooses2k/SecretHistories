class_name WallSegmentCellFilter
extends CellFilter

## Wall segment analysis for multi-tile objects

### Member Variables and Dependencies -------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

var object_size: Vector2 = Vector2.ONE

# Internal wall data structure - exact copy from crypt_room_walls.gd
var cells := {
	WorldData.Direction.NORTH: [],
	WorldData.Direction.EAST: [],
	WorldData.Direction.SOUTH: [],
	WorldData.Direction.WEST: [],
}

# Array of Directions - exact copy from crypt_room_walls.gd
var main_walls := []

#--- private variables - order: export > normal var > onready -------------------------------------

var _rng := RandomNumberGenerator.new()

### -----------------------------------------------------------------------------------------------

### Public Methods --------------------------------------------------------------------------------

## Core interface method - returns empty array since this filter works differently
## Use get_wall_segments_for_placement() instead for wall segment processing
func filter_cells(world_data: WorldData, room_data: RoomData, rng: RandomNumberGenerator = null) -> Array:
	if rng:
		_rng = rng
	
	# Initialize the wall analysis using exact crypt_room_walls logic
	_init_from_room(world_data, room_data, object_size, _rng)
	
	# Return empty array - this filter works through get_wall_segments_for_placement()
	return []


## Main method for getting wall segments ready for placement
## Replicates the exact flow from generate_sarcophagus.gd
func get_wall_segments_for_placement(world_data: WorldData, room_data: RoomData, rng: RandomNumberGenerator) -> Dictionary:
	_rng = rng
	
	# Initialize wall analysis using exact crypt_room_walls logic
	_init_from_room(world_data, room_data, object_size, _rng)
	
	var placement_data := {
		"main_wall_segments": [],
		"other_wall_segments": [],
		"walls_data": self  # Return self to provide access to internal data
	}
	
	# Process main walls first (exact flow from generate_sarcophagus.gd:56-57)
	for direction in main_walls:
		var segments := _get_segments_for_direction(world_data, direction)
		placement_data.main_wall_segments.append_array(segments)
	
	# Process other walls (exact flow from generate_sarcophagus.gd:59-62)
	for direction in cells:
		if direction in main_walls:
			continue
		var segments := _get_segments_for_direction(world_data, direction)
		placement_data.other_wall_segments.append_array(segments)
	
	return placement_data


## Get remaining rectangle for center placement
func get_remaining_rect(room: RoomData) -> Rect2:
	var value := room.rect2
	for direction in cells:
		var segments := cells[direction] as Array

		match direction:
			WorldData.Direction.NORTH:
				if segments.is_empty():
					value.position.y += 1
					value.size.y -= 1
				else:
					value.position.y += object_size.y
					value.size.y -= object_size.y
			WorldData.Direction.WEST:
				if segments.is_empty():
					value.position.x += 1
					value.size.x -= 1
				else:
					value.position.x += object_size.x
					value.size.x -= object_size.x
			WorldData.Direction.SOUTH:
				if segments.is_empty():
					value.size.y -= 1
				else:
					value.size.y -= object_size.y
			WorldData.Direction.EAST:
				if segments.is_empty():
					value.size.x -= 1
				else:
					value.size.x -= object_size.x

	return value


## Check if center placement is valid
func can_place_center_object(remaining_rect: Rect2) -> bool:
	return remaining_rect.size >= object_size


## Calculate center position
func calculate_center_position(remaining_rect: Rect2, cell_size: float) -> Dictionary:
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
func get_center_cells(world_data: WorldData, placement_rect: Rect2) -> Array:
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


## Calculate rotation
func calculate_rotation(vertical_center_rotation: float) -> float:
	var rotation := 0.0
	if not main_walls.is_empty():
		var main_wall = main_walls[0]
		if main_wall == WorldData.Direction.EAST or main_wall == WorldData.Direction.WEST:
			rotation = deg_to_rad(vertical_center_rotation)
	return rotation


## Process wall segments with callback
func process_wall_segments(world_data: WorldData, direction: int, callback: Callable) -> void:
	var segments := get_sanitized_segments_for(world_data, direction, object_size)
	for value in segments:
		var segment := value as Array
		var surplus_cells := segment.size() % int(object_size.x)

		if surplus_cells == 0:
			for index in range(0, segment.size(), object_size.x):
				var slice = segment.slice(index, index + object_size.x)
				var segment_cells := _get_cells_for_wall_segment(world_data, slice, direction)
				callback.call(segment_cells, direction)
		else:
			var segment_cells := _get_cells_for_wall_segment(world_data, segment, direction)
			var wall_offset := _get_wall_offset(direction, surplus_cells) * world_data.CELL_SIZE
			callback.call(segment_cells, direction, wall_offset)


## Configuration methods
func set_object_size(size: Vector2) -> WallSegmentCellFilter:
	object_size = size
	return self

### -----------------------------------------------------------------------------------------------

### Private Methods -------------------------------------------------------------------------------

## Initialize from room - EXACT copy from crypt_room_walls.gd:init_from_room
func _init_from_room(world_data: WorldData, crypt: RoomData, sarco_tile_size: Vector2, rng: RandomNumberGenerator) -> void:
	_rng = rng
	_handle_wall_cells(world_data, crypt, sarco_tile_size.x)
	_handle_main_wall(world_data, crypt)


## Handle wall cells - EXACT copy from crypt_room_walls.gd:_handle_wall_cells
func _handle_wall_cells(world_data: WorldData, crypt: RoomData, sarco_length: int) -> void:
	var possible_cells := {
		WorldData.Direction.NORTH: [],
		WorldData.Direction.EAST: [],
		WorldData.Direction.SOUTH: [],
		WorldData.Direction.WEST: [],
	}
	
	_build_possible_cells(world_data, crypt, possible_cells)
	_group_wall_cells_by_valid_segments(world_data, sarco_length, possible_cells)


## Build possible cells - EXACT copy from crypt_room_walls.gd:_build_possible_cells
func _build_possible_cells(world_data: WorldData, crypt: RoomData, possible_cells: Dictionary) -> void:
	for cell_index in crypt.cell_indexes:
		if crypt.has_doorway_on(cell_index):
			continue
		
		for direction in WorldData.Direction.values():
			if direction == WorldData.Direction.DIRECTION_MAX:
				continue
			
			var edge_type := world_data.get_wall_type(cell_index, direction)
			match edge_type:
				WorldData.EdgeType.WALL:
					possible_cells[direction].append(cell_index)


## Group wall cells by valid segments - EXACT copy from crypt_room_walls.gd:_group_wall_cells_by_valid_segments
func _group_wall_cells_by_valid_segments(world_data: WorldData, sarco_length: int, possible_cells: Dictionary) -> void:
	for direction in possible_cells:
		if possible_cells[direction].is_empty():
			continue
		
		var neighbour_cells := []
		var length_direction := world_data.direction_rotate_cw(direction)
		if direction == WorldData.Direction.SOUTH or direction == WorldData.Direction.WEST:
			length_direction = world_data.direction_rotate_ccw(direction)
		
		for index in range(1, possible_cells[direction].size()):
			var previous_cell := possible_cells[direction][index - 1] as int
			var current_cell := possible_cells[direction][index] as int
			if current_cell == world_data.get_neighbour_cell(previous_cell, length_direction):
				if neighbour_cells.is_empty():
					neighbour_cells.append(previous_cell)
				neighbour_cells.append(current_cell)
			else:
				if neighbour_cells.size() >= sarco_length:
					cells[direction].append(neighbour_cells.duplicate())
				neighbour_cells.clear()
		
		if neighbour_cells.size() >= sarco_length:
			cells[direction].append(neighbour_cells.duplicate())


## Handle main wall - EXACT copy from crypt_room_walls.gd:_handle_main_wall
func _handle_main_wall(world_data: WorldData, crypt: RoomData) -> void:
	var doorway_walls := crypt.get_doorway_directions()
	if doorway_walls.size() == 1:
		var opposing_wall := world_data.direction_inverse(doorway_walls[0])
		main_walls.append(opposing_wall)
		cells[doorway_walls[0]].clear()
	elif doorway_walls.size() == 2:
		var doorway1_direction = doorway_walls[0]
		var doorway2_direction = doorway_walls[1]
		
		if world_data.direction_inverse(doorway1_direction) == doorway2_direction:
			for direction in doorway_walls:
				var perpendicular_direction := world_data.direction_rotate_cw(direction)
				main_walls.append(perpendicular_direction)
		else:
			var opposing_walls := [
					world_data.direction_inverse(doorway1_direction),
					world_data.direction_inverse(doorway2_direction),
			]
			
			_set_biggest_wall_as_main(opposing_walls)
		
		cells[doorway1_direction].clear()
		cells[doorway2_direction].clear()
	elif doorway_walls.size() == 3:
		for direction in cells:
			if doorway_walls.has(direction):
				cells[direction].clear()
			else:
				main_walls.append(direction)


## Set biggest wall as main - EXACT copy from crypt_room_walls.gd:_set_biggest_wall_as_main
func _set_biggest_wall_as_main(directions) -> void:
	var total_sizes := _get_total_cells_in(directions)
	if total_sizes[directions[0]] == total_sizes[directions[1]]:
		var chosen_direction = _rng.randi() % directions.size()
		main_walls.append(directions[chosen_direction])
	elif total_sizes[directions[0]] > total_sizes[directions[1]]:
		main_walls.append(directions[0])
	else:
		main_walls.append(directions[1])


## Get total cells in - EXACT copy from crypt_room_walls.gd:_get_total_cells_in
func _get_total_cells_in(directions: Array) -> Dictionary:
	var total_sizes := {}
	
	for direction in directions:
		if not direction in total_sizes:
			total_sizes[direction] = 0
		
		for array in cells[direction]:
			var segment := array as Array
			total_sizes[direction] += segment.size()
	
	return total_sizes


## Get sanitized segments for direction - EXACT copy from crypt_room_walls.gd:get_sanitized_segments_for
func get_sanitized_segments_for(world_data: WorldData, wall_direction: int, sarco_tile_size: Vector2) -> Array:
	var sanitized_segments := []
	var free_segments := []
	
	var width_direction := world_data.direction_inverse(wall_direction)
	for value in cells[wall_direction]:
		var raw_segment := value.duplicate() as Array
		var indexes_to_remove := []
		for index in raw_segment.size():
			var current_cell := raw_segment[index] as int
			var is_free := world_data.is_cell_free(current_cell)
			for _index in sarco_tile_size.y - 1:
				if is_free:
					current_cell = world_data.get_neighbour_cell(current_cell, width_direction)
					is_free = world_data.is_cell_free(current_cell)
			
			if not is_free:
				indexes_to_remove.append(index)
		
		if not indexes_to_remove.is_empty():
			for r_index in range(indexes_to_remove.size()-1, -1, -1):
				raw_segment.remove_at(indexes_to_remove[r_index])
			
			if raw_segment.size() >= sarco_tile_size.x:
				free_segments.append(raw_segment)
		else:
			free_segments.append(raw_segment)
	
	for value in free_segments:
		var segment := value as Array
		var sarcos_per_segment := segment.size() / int(sarco_tile_size.x)
		var surplus_tiles := segment.size() % int(sarco_tile_size.x)
		var centralized_and_fit_segments := _handle_segments_size(
				surplus_tiles, sarcos_per_segment, segment, sarco_tile_size
		)
		sanitized_segments.append_array(centralized_and_fit_segments)
	
	return sanitized_segments


## Handle segments size - EXACT copy from crypt_room_walls.gd:_handle_segments_size
func _handle_segments_size(surplus_tiles: int, sarcos_per_segment: int, segment: Array, sarco_tile_size: Vector2) -> Array:
	var final_segments := []
	
	if surplus_tiles == 0:
		final_segments.append(segment)
	elif surplus_tiles % 2 == 0:
		for _index in sarcos_per_segment:
			segment.pop_back()
			segment.pop_front()
		final_segments.append(segment)
	elif surplus_tiles % 2 == 1:
		if sarcos_per_segment % 2 == 0:
			var middle_index := segment.size() / 2
			final_segments.append(segment.slice(0, middle_index))
			final_segments.append(segment.slice(middle_index+1, segment.size()))
		else:
			if sarcos_per_segment > 1:
				surplus_tiles += sarco_tile_size.x
				sarcos_per_segment -= 1
				final_segments = _handle_segments_size(
					surplus_tiles, sarcos_per_segment, segment, sarco_tile_size
				)
			elif surplus_tiles > 1:
				surplus_tiles -= 1
				final_segments = _handle_segments_size(
					surplus_tiles, sarcos_per_segment, segment, sarco_tile_size
				)
			elif surplus_tiles == 1:
				final_segments.append(segment)
	
	return final_segments


## Get segments for direction - helper for main processing
func _get_segments_for_direction(world_data: WorldData, direction: int) -> Array:
	var segments := []
	var sanitized_segments := get_sanitized_segments_for(world_data, direction, object_size)
	
	for segment in sanitized_segments:
		var surplus_cells: int = segment.size() % int(object_size.x)
		segments.append({
			"cells": segment,
			"direction": direction,
			"surplus_cells": surplus_cells
		})
	
	return segments


## Get cells for wall segment
func _get_cells_for_wall_segment(world_data: WorldData, segment: Array, direction: int) -> Array:
	var width_direction := world_data.direction_inverse(direction)
	var segment_cells := []

	for cell_index in segment:
		segment_cells.append(cell_index)
		for _width in object_size.y - 1:
			cell_index = world_data.get_neighbour_cell(cell_index, width_direction)
			segment_cells.append(cell_index)

	return segment_cells


## Get wall offset
func _get_wall_offset(direction: int, surplus_cells: int) -> Vector3:
	var center_offset := surplus_cells / 2.0
	match direction:
		WorldData.Direction.NORTH, WorldData.Direction.SOUTH:
			return Vector3(center_offset, 0, 0)
		WorldData.Direction.EAST, WorldData.Direction.WEST:
			return Vector3(0, 0, center_offset)
	return Vector3.ZERO

### -----------------------------------------------------------------------------------------------
