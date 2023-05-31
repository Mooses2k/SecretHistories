# Write your doc string for this file here
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

# Rooms must have both sides greater or equal to this value to be considered 
# for spawning candelabra
export var _size_threshold := 6
export(float, 0.0,1.0,0.01) var _room_chance := 0.6
export var _spawn_list_resource: Resource = null

var _rng := RandomNumberGenerator.new()

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
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
		if room_data.is_min_dimension_greater_or_equal_to(_size_threshold):
			valid_rooms.append(room_data)
	
	print("valid rooms for candelabra: %s"%[valid_rooms])
	
	return valid_rooms


func _handle_candelabra(world_data: WorldData, room_data: RoomData) -> void:
	var spawn_list := _spawn_list_resource as ObjectSpawnList
	
	var corners := room_data.get_corner_position_vectors()
	for entry in corners:
		var corner := entry as Vector2
		var corner_index := world_data.get_cell_index_from_int_position(corner.x, corner.y)
		if not world_data.is_cell_free(corner_index):
			continue
		
		var spawn_data := spawn_list.get_random_spawn_data()
		if not spawn_data.scene_path.empty():
			print("spawning candelabra at: %s | %s"%[corner_index, spawn_data.scene_path])
			world_data.set_spawn_data_to_cell(corner_index, spawn_data)
		else:
			print("No candelabra to spawn in this corner: %s"%[corner_index])

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
