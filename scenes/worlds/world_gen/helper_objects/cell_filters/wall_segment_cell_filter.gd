class_name WallSegmentCellFilter
extends CellFilter

## Complex wall segment analysis for multi-tile objects
## Extracts and consolidates logic from crypt_room_walls.gd
## Uses base class utilities for all WorldData operations

var object_size: Vector2 = Vector2.ONE
var prefer_main_walls: bool = true
var avoid_doorways: bool = true
var min_segment_size: int = 3


func filter_cells(world_data: WorldData, room_data: RoomData, rng: RandomNumberGenerator = null) -> Array:
	if not room_data:
		return []
	
	# Analyze wall segments using extracted crypt_room_walls logic
	var wall_segments := _analyze_wall_segments(world_data, room_data)
	var suitable_segments := _filter_suitable_segments(wall_segments)
	var placement_cells := _get_placement_cells_from_segments(world_data, suitable_segments)
	
	return placement_cells


func _analyze_wall_segments(world_data: WorldData, room_data: RoomData) -> Array:
	var segments := []
	var room_cells := room_data.cell_indexes
	
	# Find consecutive wall cells for each direction
	for direction in WorldData.Direction.values():
		if direction == WorldData.Direction.DIRECTION_MAX:
			continue
		
		var wall_cells := _find_wall_cells_in_direction(world_data, room_cells, direction)
		var consecutive_segments := _group_consecutive_cells(wall_cells)
		
		for segment in consecutive_segments:
			segments.append({
				"direction": direction,
				"cells": segment,
				"length": segment.size(),
				"has_doorway": _segment_has_doorway(world_data, segment, direction)
			})
	
	return segments


func _filter_suitable_segments(segments: Array) -> Array:
	var suitable := []
	
	for segment in segments:
		# Check minimum size requirement
		if segment.length < min_segment_size:
			continue
		
		# Skip segments with doorways if avoiding them
		if avoid_doorways and segment.has_doorway:
			continue
		
		# Check if segment can fit the object
		if segment.length >= object_size.x:
			suitable.append(segment)
	
	# Sort by preference (main walls first, then by length)
	if prefer_main_walls:
		suitable.sort_custom(_compare_segments_by_preference)
	
	return suitable


func _get_placement_cells_from_segments(world_data: WorldData, segments: Array) -> Array:
	var placement_cells := []
	
	for segment in segments:
		# Calculate optimal placement within segment
		var segment_cells: Array = segment.cells
		var placement_positions := _calculate_centered_placements(segment_cells)
		
		# Validate each placement position
		for pos in placement_positions:
			var cells_for_object := _get_cells_for_object_at_position(world_data, pos)
			if _validate_object_placement(world_data, cells_for_object):
				placement_cells.append_array(cells_for_object)
	
	return placement_cells


func _find_wall_cells_in_direction(world_data: WorldData, room_cells: Array, direction: int) -> Array:
	var wall_cells := []
	
	for cell_index in room_cells:
		var wall_type := get_wall_type(world_data, cell_index, direction)
		if wall_type == WorldData.EdgeType.WALL:
			wall_cells.append(cell_index)
	
	return wall_cells


func _group_consecutive_cells(cells: Array) -> Array:
	if cells.is_empty():
		return []
	
	cells.sort()
	var segments := []
	var current_segment := [cells[0]]
	
	for i in range(1, cells.size()):
		var current_cell: int = cells[i]
		var previous_cell: int = cells[i - 1]
		
		# Check if cells are adjacent (simplified - would need proper adjacency check)
		if current_cell - previous_cell == 1:
			current_segment.append(current_cell)
		else:
			segments.append(current_segment.duplicate())
			current_segment = [current_cell]
	
	segments.append(current_segment)
	return segments


func _segment_has_doorway(world_data: WorldData, segment_cells: Array, direction: int) -> bool:
	for cell_index in segment_cells:
		if has_door_in_direction(world_data, cell_index, direction):
			return true
	return false


func _compare_segments_by_preference(a: Dictionary, b: Dictionary) -> bool:
	# Prefer longer segments, then segments without doorways
	if a.length != b.length:
		return a.length > b.length
	return not a.has_doorway and b.has_doorway


func _calculate_centered_placements(segment_cells: Array) -> Array:
	var placements := []
	var segment_length := segment_cells.size()
	var object_width := int(object_size.x)
	
	# Calculate how many positions can fit the object
	var possible_positions := segment_length - object_width + 1
	
	if possible_positions > 0:
		# Prefer center placement
		var center_start := (segment_length - object_width) / 2
		placements.append(center_start)
		
		# Add alternative positions if needed
		for i in range(possible_positions):
			if i != center_start:
				placements.append(i)
	
	return placements


func _get_cells_for_object_at_position(world_data: WorldData, position: int) -> Array:
	# This would calculate the actual cells needed for the object
	# Simplified implementation - would need proper coordinate conversion
	var cells := []
	for i in range(int(object_size.x)):
		for j in range(int(object_size.y)):
			cells.append(position + i + j * world_data.world_size_x)
	return cells


func _validate_object_placement(world_data: WorldData, cells: Array) -> bool:
	return filter_available_cells(world_data, cells).size() == cells.size()


func set_object_size(size: Vector2) -> WallSegmentCellFilter:
	object_size = size
	return self


func set_prefer_main_walls(prefer: bool) -> WallSegmentCellFilter:
	prefer_main_walls = prefer
	return self


func set_avoid_doorways(avoid: bool) -> WallSegmentCellFilter:
	avoid_doorways = avoid
	return self


func set_min_segment_size(size: int) -> WallSegmentCellFilter:
	min_segment_size = size
	return self