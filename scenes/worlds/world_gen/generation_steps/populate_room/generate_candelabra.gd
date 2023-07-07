# Write your doc string for this file here
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const UNLIT_KEYWORD = "unlit"
const MAX_X_UNLIT_ROTATION = deg2rad(30)
const MAX_Z_UNLIT_ROTATION = deg2rad(30)

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

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
	var crypt_rooms := data.get_rooms_of_type(RoomData.OriginalPurpose.CRYPT)
	if crypt_rooms.empty():
		return
	
	_rng.seed = generation_seed
	
	for entry in crypt_rooms:
		if _rng.randf() >= _room_chance:
			_handle_candelabra(data, entry)


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
		var spawn_data := spawn_list.get_random_spawn_data(_rng)
		if not spawn_data.scene_path.empty():
			spawn_data.set_center_position_in_cell(cell_position)
			if spawn_data.scene_path.find(UNLIT_KEYWORD) != -1:
				spawn_data.set_random_rotation_in_all_axis(
						_rng, 
						MAX_X_UNLIT_ROTATION, 
						TAU, 
						MAX_Z_UNLIT_ROTATION
				)
			else:
				var facing_angle := corners.get_facing_angle_for(key)
				spawn_data.set_y_rotation(facing_angle)
			
			world_data.set_object_spawn_data_to_cell(corner_index, spawn_data)
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
		if world_data.has_door(corner_index, direction):
			value = true
			break
	
	return value

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
