class_name ProximityGroupingCellFilter
extends CellFilter

## Handles proximity-based grouping of similar objects
## For stacking items like barrels and crates
## Supports multiple grouping types simultaneously

enum GroupingType {
	ADJACENT,      # Objects must be directly adjacent
	CLUSTERED,     # Objects within a small radius
	SCATTERED,     # Objects spread out with minimum distance
	STACKED        # Objects that can stack vertically
}

var allowed_grouping_types: Array = [GroupingType.ADJACENT]  # Array of allowed types
var group_size_min: int = 2
var group_size_max: int = 4
var proximity_radius: int = 2
var min_separation: int = 3
var grouping_tags: Array = []


func filter_cells(world_data: WorldData, room_data: RoomData, rng: RandomNumberGenerator = null) -> Array:
	if not room_data:
		return []
	
	var all_candidate_cells := []
	
	# Apply all allowed grouping types and combine results
	for grouping_type in allowed_grouping_types:
		var type_candidates := []
		
		match grouping_type:
			GroupingType.ADJACENT:
				type_candidates = _get_adjacent_grouping_cells(world_data, room_data)
			GroupingType.CLUSTERED:
				type_candidates = _get_clustered_grouping_cells(world_data, room_data)
			GroupingType.SCATTERED:
				type_candidates = _get_scattered_grouping_cells(world_data, room_data)
			GroupingType.STACKED:
				type_candidates = _get_stacked_grouping_cells(world_data, room_data)
		
		# Add unique candidates (avoid duplicates)
		for candidate in type_candidates:
			if candidate not in all_candidate_cells:
				all_candidate_cells.append(candidate)
	
	return all_candidate_cells


func _get_adjacent_grouping_cells(world_data: WorldData, room_data: RoomData) -> Array:
	var candidate_cells := []
	var room_cells := filter_available_cells(world_data, room_data.cell_indexes)
	
	var existing_object_cells := _find_existing_groupable_objects(world_data, room_data)
	
	if existing_object_cells.is_empty():
		return _find_new_group_locations(world_data, room_cells)
	else:
		for existing_cell in existing_object_cells:
			var adjacent_cells := _get_adjacent_available_cells(world_data, existing_cell)
			candidate_cells.append_array(adjacent_cells)
	
	return candidate_cells


func _get_clustered_grouping_cells(world_data: WorldData, room_data: RoomData) -> Array:
	var candidate_cells := []
	var room_cells := filter_available_cells(world_data, room_data.cell_indexes)
	
	var existing_object_cells := _find_existing_groupable_objects(world_data, room_data)
	
	if existing_object_cells.is_empty():
		return _find_new_group_locations(world_data, room_cells)
	else:
		for existing_cell in existing_object_cells:
			var nearby_cells := _get_cells_within_radius(world_data, existing_cell, proximity_radius)
			var available_nearby := filter_available_cells(world_data, nearby_cells)
			candidate_cells.append_array(available_nearby)
	
	return candidate_cells


func _get_scattered_grouping_cells(world_data: WorldData, room_data: RoomData) -> Array:
	var candidate_cells := []
	var room_cells := filter_available_cells(world_data, room_data.cell_indexes)
	
	var existing_object_cells := _find_existing_groupable_objects(world_data, room_data)
	
	for cell_index in room_cells:
		var is_far_enough := true
		
		for existing_cell in existing_object_cells:
			var distance := _calculate_cell_distance(world_data, cell_index, existing_cell)
			if distance < min_separation:
				is_far_enough = false
				break
		
		if is_far_enough:
			candidate_cells.append(cell_index)
	
	return candidate_cells


func _get_stacked_grouping_cells(world_data: WorldData, room_data: RoomData) -> Array:
	var candidate_cells := []
	
	var existing_object_cells := _find_existing_groupable_objects(world_data, room_data)
	
	# For stacking, return existing cells for vertical stacking
	candidate_cells.append_array(existing_object_cells)
	
	# Also include new locations for base stacks
	var room_cells := filter_available_cells(world_data, room_data.cell_indexes)
	var new_stack_locations := _find_new_group_locations(world_data, room_cells)
	candidate_cells.append_array(new_stack_locations)
	
	return candidate_cells


func _get_adjacent_available_cells(world_data: WorldData, center_cell: int) -> Array:
	var adjacent_cells := []
	
	for direction in WorldData.Direction.values():
		if direction == WorldData.Direction.DIRECTION_MAX:
			continue
		
		var neighbor_cell := get_adjacent_cell(world_data, center_cell, direction)
		if neighbor_cell >= 0 and is_cell_available(world_data, neighbor_cell):
			adjacent_cells.append(neighbor_cell)
	
	return adjacent_cells


func _get_cells_within_radius(world_data: WorldData, center_cell: int, radius: int) -> Array:
	var cells_in_radius := []
	var center_pos := get_int_position_from_cell(world_data, center_cell)
	var center_x: int = center_pos[0]
	var center_y: int = center_pos[1]
	
	for x_offset in range(-radius, radius + 1):
		for y_offset in range(-radius, radius + 1):
			var check_x := center_x + x_offset
			var check_y := center_y + y_offset
			var check_cell := get_cell_index(world_data, check_x, check_y)
			
			if check_cell >= 0:
				var distance := sqrt(x_offset * x_offset + y_offset * y_offset)
				if distance <= radius:
					cells_in_radius.append(check_cell)
	
	return cells_in_radius


func _calculate_cell_distance(world_data: WorldData, cell1: int, cell2: int) -> float:
	var pos1 := get_int_position_from_cell(world_data, cell1)
	var pos2 := get_int_position_from_cell(world_data, cell2)
	
	var dx: int = pos1[0] - pos2[0]
	var dy: int = pos1[1] - pos2[1]
	
	return sqrt(dx * dx + dy * dy)


func _find_existing_groupable_objects(world_data: WorldData, room_data: RoomData) -> Array:
	var existing_cells := []
	var objects_to_spawn := world_data.get_objects_to_spawn()
	
	for cell_index in objects_to_spawn:
		if cell_index in room_data.cell_indexes:
			var spawn_data = objects_to_spawn[cell_index]
			if _object_has_grouping_tags(spawn_data):
				existing_cells.append(cell_index)
	
	return existing_cells


func _object_has_grouping_tags(spawn_data) -> bool:
	if grouping_tags.is_empty():
		return false
	
	var scene_path: String = spawn_data.scene_path.to_lower()
	
	for tag in grouping_tags:
		if scene_path.contains(tag.to_lower()):
			return true
	
	return false


func _find_new_group_locations(world_data: WorldData, available_cells: Array) -> Array:
	var group_locations := []
	
	for cell_index in available_cells:
		if _can_place_group_at(world_data, cell_index, group_size_min):
			group_locations.append(cell_index)
	
	return group_locations


func _can_place_group_at(world_data: WorldData, start_cell: int, group_size: int) -> bool:
	var available_count := 1
	var adjacent_cells := _get_adjacent_available_cells(world_data, start_cell)
	available_count += adjacent_cells.size()
	
	return available_count >= group_size


## Configuration methods - now supports multiple types
func set_allowed_grouping_types(types: Array) -> ProximityGroupingCellFilter:
	allowed_grouping_types = types
	return self


func add_grouping_type(type: GroupingType) -> ProximityGroupingCellFilter:
	if type not in allowed_grouping_types:
		allowed_grouping_types.append(type)
	return self


func remove_grouping_type(type: GroupingType) -> ProximityGroupingCellFilter:
	allowed_grouping_types.erase(type)
	return self


func set_group_size_range(min_size: int, max_size: int) -> ProximityGroupingCellFilter:
	group_size_min = min_size
	group_size_max = max_size
	return self


func set_proximity_radius(radius: int) -> ProximityGroupingCellFilter:
	proximity_radius = radius
	return self


func set_min_separation(separation: int) -> ProximityGroupingCellFilter:
	min_separation = separation
	return self


func set_grouping_tags(tags: Array) -> ProximityGroupingCellFilter:
	grouping_tags = tags
	return self