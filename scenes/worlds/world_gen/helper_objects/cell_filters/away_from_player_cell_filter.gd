class_name AwayFromPlayerCellFilter
extends CellFilter

## Filters cells away from player position
## Consolidates logic from character_spawner.gd:93-121

var player_position: Vector3
var min_distance: float = 0.0


func filter_cells(world_data: WorldData, room_data: RoomData, rng: RandomNumberGenerator = null) -> Array:
	if player_position == Vector3.ZERO:
		return []
	
	# Use base class utilities for coordinate conversion
	var player_cell := get_cell_from_local_position(world_data, player_position)
	var player_int_coords := get_int_position_from_cell(world_data, player_cell)
	
	# Choose opposite corner from player
	var try_pos := Vector3(world_data.world_size_x - 1, 0, world_data.world_size_z - 1)
	
	if player_int_coords[0] > world_data.world_size_x / 2:
		try_pos.x = 0
	if player_int_coords[1] > world_data.world_size_z / 2:
		try_pos.z = 0
	
	# Use base class utility for coordinate conversion
	var target_cell := get_cell_index(world_data, try_pos.x, try_pos.z)
	
	# Find closest navigable position
	var try_pos_world := get_cell_position(world_data, target_cell)
	var final_cell := get_cell_from_local_position(world_data, try_pos_world)
	
	# Use base class utility for availability check
	return [final_cell] if is_cell_available(world_data, final_cell) else []


func set_player_position(pos: Vector3) -> AwayFromPlayerCellFilter:
	player_position = pos
	return self


func set_min_distance(distance: float) -> AwayFromPlayerCellFilter:
	min_distance = distance
	return self