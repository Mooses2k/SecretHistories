# Write your doc string for this file here
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

export var single_tile_width := 2
export var single_tile_height := 2
export var player_offset := Vector2.ONE

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

# Randomly generates the starting room, and add it to an array of Rect2 into gen_data, 
# under the key ROOM_ARRAY_KEY
func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	_generate_rooms(data, gen_data, generation_seed)


func _generate_rooms(data : WorldData, gen_data : Dictionary, generation_seed : int):
	var random : RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = generation_seed
	
	var rooms: Array = gen_data[ROOM_ARRAY_KEY] if gen_data.has(ROOM_ARRAY_KEY) else Array()
	
	var entry_room := _gen_staircase_room_rect(data, random)
	data.fill_room_data(entry_room, RoomData.OriginalPurpose.UP_STAIRCASE)
	data.player_spawn_position = entry_room.position + player_offset
	rooms.append(entry_room)
	
	var exit_room := _gen_staircase_room_rect(data, random)
	data.fill_room_data(exit_room, RoomData.OriginalPurpose.DOWN_STAIRCASE)
	rooms.append(exit_room)
	
	gen_data[ROOM_ARRAY_KEY] = rooms


func _gen_staircase_room_rect(data : WorldData, random : RandomNumberGenerator) -> Rect2:
	var value := Rect2()
	
	var p_x = random.randi_range(1, data.get_size_x() - 1 - single_tile_width)
	var p_z = random.randi_range(1, data.get_size_z() - 1 - single_tile_height)
	
	value = Rect2(p_x, p_z, single_tile_width, single_tile_height)
	return value


### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
