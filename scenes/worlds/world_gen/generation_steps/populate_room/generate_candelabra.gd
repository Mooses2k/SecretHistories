# Write your doc string for this file here
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const UNLIT_KEYWORD = "unlit"

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

# Rooms must have both sides greater or equal to this value to be considered 
# for spawning candelabra
export var _single_tile_size_threshold := 6
export(float, 0.0,1.0,0.01) var _room_chance := 0.6
export var _spawn_list_resource: Resource = null

var _rng := RandomNumberGenerator.new()

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _execute_step(data : WorldData, _gen_data : Dictionary, generation_seed : int):
	_rng.seed = generation_seed
	
	var all_rooms := data.get_all_rooms()
	var valid_rooms := _get_valid_rooms(all_rooms)
	for entry in valid_rooms:
		if _rng.randf() >= _room_chance:
			_handle_candelabra(data, entry)


func _get_valid_rooms(p_array: Array) -> Array:
	var valid_rooms := []
	
	for entry in p_array:
		var room_data := entry as RoomData
		if room_data.is_min_dimension_greater_or_equal_to(_single_tile_size_threshold):
			valid_rooms.append(room_data)
	
#	print("valid rooms for candelabra: %s"%[valid_rooms])
	
	return valid_rooms


func _handle_candelabra(world_data: WorldData, room_data: RoomData) -> void:
	var spawn_list := _spawn_list_resource as ObjectSpawnList
	
	var corners := room_data.get_corners_data()
	for key in corners.corner_positions:
		var corner := corners.corner_positions[key] as Vector2
		var corner_index := world_data.get_cell_index_from_int_position(int(corner.x), int(corner.y))
		var corner_directions := _get_walls_world_data_directions_for(key)
		
		if (
				not world_data.is_cell_free(corner_index) 
				or _is_corner_next_to_door(world_data, corner_index, corner_directions)
		):
			continue
		
		var cell_position := world_data.get_local_cell_position(corner_index)
		var spawn_data := spawn_list.get_random_spawn_data()
		if not spawn_data.scene_path.empty():
			spawn_data.set_center_position_in_cell(cell_position)
			if spawn_data.scene_path.find(UNLIT_KEYWORD) != -1:
				spawn_data.set_random_rotation_in_all_axis(_rng)
			else:
				var facing_angle := corners.get_facing_angle_for(key)
				spawn_data.set_y_rotation(facing_angle)
			
			world_data.set_spawn_data_to_cell(corner_index, spawn_data)
		else:
#			print("No candelabra to spawn in this corner: %s"%[corner_index])
			pass


func _get_walls_world_data_directions_for(corner_type: int) -> Array:
		var value := []
		
		match corner_type:
			CORNER_TOP_LEFT:
				value = [WorldData.Direction.NORTH, WorldData.Direction.WEST]
			CORNER_TOP_RIGHT:
				value = [WorldData.Direction.NORTH, WorldData.Direction.EAST]
			CORNER_BOTTOM_RIGHT:
				value = [WorldData.Direction.SOUTH, WorldData.Direction.EAST]
			CORNER_BOTTOM_LEFT:
				value = [WorldData.Direction.SOUTH, WorldData.Direction.WEST]
			_:
				push_error("Invalid corner_type: %s"%[corner_type])
		
		return value


func _is_corner_next_to_door(
		world_data: WorldData, corner_index: int, corner_directions: Array
) -> bool:
	var value := false
	
	world_data
	
	for direction in corner_directions:
		var wall_type := world_data.get_wall_type(corner_index, direction)
		if wall_type == world_data.EdgeType.DOOR:
			value = true
			break
	
	return value

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
