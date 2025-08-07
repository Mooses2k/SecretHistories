class_name PillarPlacementCellFilter
extends CellFilter

## Vertex-based pillar placement for wall-mounted objects
## Consolidates and generalizes logic from generate_wall_objects.gd
## Handles pillar sides, directional validation, and adjacent cell pair analysis

var required_adjacent_cell_types: Array = [WorldData.CellType.CORRIDOR]
var spawn_chance: float = 1.0
var wall_offset_multiplier: float = 0.225
var wall_mount_height: float = 1.6


func filter_cells(world_data: WorldData, room_data: RoomData, rng: RandomNumberGenerator = null) -> Array:
	var valid_pillar_sides := _find_valid_pillar_sides(world_data)
	var filtered_sides := _apply_spawn_chance_filter(valid_pillar_sides, rng)
	var placement_cells := _convert_pillar_sides_to_cells(world_data, filtered_sides)
	
	return placement_cells


func _find_valid_pillar_sides(world_data: WorldData) -> Array:
	var valid_sides := []
	
	# Check each position for pillars (pillars are at vertices)
	for x in range(1, world_data.world_size_x - 1):
		for z in range(1, world_data.world_size_z - 1):
			var pillar_cell_index := get_cell_index(world_data, x, z)
			
			# Check if there's a pillar at this vertex
			if world_data.get_pillar_tile_index(pillar_cell_index) == -1:
				continue
			
			# Check each direction for valid wall placement
			for direction in WorldData.Direction.values():
				if direction == WorldData.Direction.DIRECTION_MAX:
					continue
				
				if _is_valid_pillar_side_for_vertex(world_data, x, z, direction):
					valid_sides.append({
						"pillar_x": x,
						"pillar_z": z,
						"direction": direction,
						"position": get_cell_position(world_data, pillar_cell_index)
					})
	
	return valid_sides


func _is_valid_pillar_side_for_vertex(world_data: WorldData, pillar_x: int, pillar_z: int, direction: int) -> bool:
	# Get the two cells adjacent to this pillar side
	var cell_coords := _get_adjacent_cell_coordinates(pillar_x, pillar_z, direction)
	
	if not _are_coordinates_valid(world_data, cell_coords):
		return false
	
	# Check if both adjacent cells match required types
	for coord_pair in cell_coords:
		var cell_index := get_cell_index(world_data, coord_pair[0], coord_pair[1])
		var cell_type := get_cell_type(world_data, cell_index)
		
		if cell_type not in required_adjacent_cell_types:
			return false
	
	return true


func _get_adjacent_cell_coordinates(pillar_x: int, pillar_z: int, direction: int) -> Array:
	# Returns array of [x, z] coordinate pairs for cells adjacent to pillar side
	var coords := []
	
	match direction:
		WorldData.Direction.NORTH:  # North side of pillar
			coords = [[pillar_x - 1, pillar_z - 1], [pillar_x, pillar_z - 1]]
		WorldData.Direction.EAST:   # East side of pillar
			coords = [[pillar_x, pillar_z - 1], [pillar_x, pillar_z]]
		WorldData.Direction.SOUTH:  # South side of pillar
			coords = [[pillar_x - 1, pillar_z], [pillar_x, pillar_z]]
		WorldData.Direction.WEST:   # West side of pillar
			coords = [[pillar_x - 1, pillar_z - 1], [pillar_x - 1, pillar_z]]
	
	return coords


func _are_coordinates_valid(world_data: WorldData, coord_pairs: Array) -> bool:
	for coord_pair in coord_pairs:
		var x: int = coord_pair[0]
		var z: int = coord_pair[1]
		if x < 0 or x >= world_data.world_size_x or z < 0 or z >= world_data.world_size_z:
			return false
	return true


func _apply_spawn_chance_filter(pillar_sides: Array, rng: RandomNumberGenerator) -> Array:
	if not rng or spawn_chance >= 1.0:
		return pillar_sides
	
	var filtered_sides := []
	for side_data in pillar_sides:
		if rng.randf() <= spawn_chance:
			filtered_sides.append(side_data)
	
	return filtered_sides


func _convert_pillar_sides_to_cells(world_data: WorldData, pillar_sides: Array) -> Array:
	var placement_cells := []
	
	for pillar_data in pillar_sides:
		var pillar_position: Vector3 = pillar_data.position
		var direction: int = pillar_data.direction
		
		# Calculate wall-mounted position
		var wall_offset := _get_wall_offset_for_direction(direction)
		var directional_offset := _get_directional_cell_offset(direction, pillar_data.pillar_x, pillar_data.pillar_z)
		var base_offset := wall_offset * (WorldData.CELL_SIZE * wall_offset_multiplier)
		var object_position := pillar_position + base_offset + directional_offset
		object_position.y += wall_mount_height
		
		# Convert to cell index for placement
		var target_cell_index := world_data.get_cell_index_from_local_position(object_position)
		
		if target_cell_index != -1 and is_cell_available(world_data, target_cell_index):
			placement_cells.append(target_cell_index)
	
	return placement_cells


func _get_wall_offset_for_direction(direction: int) -> Vector3:
	match direction:
		WorldData.Direction.NORTH:
			return Vector3(0, 0, -1)
		WorldData.Direction.EAST:
			return Vector3(1, 0, 0)
		WorldData.Direction.SOUTH:
			return Vector3(0, 0, 1)
		WorldData.Direction.WEST:
			return Vector3(-1, 0, 0)
		_:
			return Vector3.ZERO


func _get_directional_cell_offset(direction: int, pillar_x: int, pillar_z: int) -> Vector3:
	# Small offset to ensure unique cell mapping per pillar side
	var base_offset := 0.01
	var coord_factor := (pillar_x + pillar_z) % 4
	
	match direction:
		WorldData.Direction.NORTH:
			return Vector3(base_offset * coord_factor, 0, -base_offset)
		WorldData.Direction.EAST:
			return Vector3(base_offset, 0, base_offset * coord_factor)
		WorldData.Direction.SOUTH:
			return Vector3(-base_offset * coord_factor, 0, base_offset)
		WorldData.Direction.WEST:
			return Vector3(-base_offset, 0, -base_offset * coord_factor)
		_:
			return Vector3.ZERO


## Configuration methods
func set_required_adjacent_cell_types(types: Array) -> PillarPlacementCellFilter:
	required_adjacent_cell_types = types
	return self


func set_spawn_chance(chance: float) -> PillarPlacementCellFilter:
	spawn_chance = chance
	return self


func set_wall_offset_multiplier(multiplier: float) -> PillarPlacementCellFilter:
	wall_offset_multiplier = multiplier
	return self


func set_wall_mount_height(height: float) -> PillarPlacementCellFilter:
	wall_mount_height = height
	return self