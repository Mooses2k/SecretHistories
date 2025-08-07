## Base class for filtering cells within validated rooms.
## Operates after room-level validation via RoomPurpose/RoomRequirements.
## Provides WorldData wrapper utilities and common filtering patterns.
class_name CellFilter
extends RefCounted


### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

## Core interface method that must be overridden by all subclasses.
##
## This method defines the main filtering logic for the specific filter implementation.
## It should return an array of cell indices that meet the filter's criteria.
##
## @param world_data: The WorldData instance containing all world information
## @param room_data: Optional RoomData instance for room-specific filtering (can be null)
## @param rng: RandomNumberGenerator instance for any random operations needed (can be null)
## @return Array of cell indices that pass the filter criteria
func filter_cells(world_data: WorldData, room_data: RoomData, rng: RandomNumberGenerator = null) -> Array:
	push_error("filter_cells() must be implemented in subclass")
	return []

### -----------------------------------------------------------------------------------------------


## ============================================================================
## WORLDDATA WRAPPER UTILITIES - Convenience wrappers, no new logic
## ============================================================================

## Gets the cell index from integer grid coordinates.
## Convenience wrapper around WorldData.get_cell_index_from_int_position().
static func get_cell_index(world_data: WorldData, x: int, y: int) -> int:
	return world_data.get_cell_index_from_int_position(x, y)


## Gets the local world position of a cell's center.
## Convenience wrapper around WorldData.get_local_cell_position().
static func get_cell_position(world_data: WorldData, cell_index: int) -> Vector3:
	return world_data.get_local_cell_position(cell_index)


## Checks if a cell is available for spawning (not occupied by objects, characters, or staircases).
## Convenience wrapper around WorldData.is_cell_free().
static func is_cell_available(world_data: WorldData, cell_index: int) -> bool:
	return world_data.is_cell_free(cell_index)


## Gets the neighbor cell in the specified direction.
## Convenience wrapper around WorldData.get_neighbour_cell().
static func get_adjacent_cell(world_data: WorldData, cell_index: int, direction: int) -> int:
	return world_data.get_neighbour_cell(cell_index, direction)


## Checks if a cell has a doorway in the specified direction.
## Convenience wrapper around WorldData.has_doorway().
static func has_door_in_direction(world_data: WorldData, cell_index: int, direction: int) -> bool:
	return world_data.has_doorway(cell_index, direction)


## Gets the type of a cell.
## Convenience wrapper around WorldData.get_cell_type().
static func get_cell_type(world_data: WorldData, cell_index: int) -> int:
	return world_data.get_cell_type(cell_index)


## Gets all cells of a specific type.
## Convenience wrapper around WorldData.get_cells_for().
static func get_cells_for_type(world_data: WorldData, cell_type: int) -> Array:
	return world_data.get_cells_for(cell_type)


## Gets the wall type for a cell in the specified direction.
## Convenience wrapper around WorldData.get_wall_type().
static func get_wall_type(world_data: WorldData, cell_index: int, direction: int) -> int:
	return world_data.get_wall_type(cell_index, direction)


## Gets the integer grid coordinates from a cell index.
## Convenience wrapper around WorldData.get_int_position_from_cell_index().
static func get_int_position_from_cell(world_data: WorldData, cell_index: int) -> Array:
	return world_data.get_int_position_from_cell_index(cell_index)


## Gets the cell index from a local world position.
## Convenience wrapper around WorldData.get_cell_index_from_local_position().
static func get_cell_from_local_position(world_data: WorldData, position: Vector3) -> int:
	return world_data.get_cell_index_from_local_position(position)


## ============================================================================
## COMMON PATTERN UTILITIES - Consolidate duplicated logic patterns
## ============================================================================

## Consolidates the duplicated "remove used cells" pattern from:
## - generate_cultists.gd:94-106
## - generate_initial_loot.gd:84-96
static func remove_used_cells(world_data: WorldData, cells: Array) -> Array:
	var filtered_cells = cells.duplicate()
	
	# Remove cells with existing objects
	for cell_index in world_data._objects_to_spawn.keys():
		filtered_cells.erase(cell_index)
	
	# Remove player spawn cells
	if world_data.is_spawn_position_valid():
		var player_cells := [
			world_data.get_player_spawn_position_as_index(RoomData.OriginalPurpose.UP_STAIRCASE),
			world_data.get_player_spawn_position_as_index(RoomData.OriginalPurpose.DOWN_STAIRCASE),
		]
		for player_cell in player_cells:
			filtered_cells.erase(player_cell)
	
	return filtered_cells


## Consolidates the pattern of filtering cells by availability
static func filter_available_cells(world_data: WorldData, cells: Array) -> Array:
	var available_cells := []
	for cell_index in cells:
		if is_cell_available(world_data, cell_index):
			available_cells.append(cell_index)
	return available_cells


## Consolidates the pattern of getting cells in a rectangular area
static func get_cells_in_rect(world_data: WorldData, rect: Rect2) -> Array:
	var cells := []
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell_index = get_cell_index(world_data, x, y)
			cells.append(cell_index)
	return cells


## Consolidates the pattern of checking if cells are adjacent to doors
static func filter_cells_away_from_doors(world_data: WorldData, cells: Array) -> Array:
	var filtered_cells := []
	for cell_index in cells:
		var has_nearby_door := false
		for direction in WorldData.Direction.values():
			if direction == WorldData.Direction.DIRECTION_MAX:
				continue
			if has_door_in_direction(world_data, cell_index, direction):
				has_nearby_door = true
				break
		if not has_nearby_door:
			filtered_cells.append(cell_index)
	return filtered_cells


## Consolidates the pattern of checking if cells are adjacent to walls
static func filter_cells_adjacent_to_walls(world_data: WorldData, cells: Array) -> Array:
	var wall_adjacent_cells := []
	for cell_index in cells:
		var is_wall_adjacent := false
		for direction in WorldData.Direction.values():
			if direction == WorldData.Direction.DIRECTION_MAX:
				continue
			var wall_type = get_wall_type(world_data, cell_index, direction)
			if wall_type == WorldData.EdgeType.WALL:
				is_wall_adjacent = true
				break
		if is_wall_adjacent:
			wall_adjacent_cells.append(cell_index)
	return wall_adjacent_cells

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
