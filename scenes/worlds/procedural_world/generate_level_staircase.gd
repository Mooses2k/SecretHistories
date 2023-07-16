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
	_fill_map_data(data, gen_data)


func _generate_rooms(data : WorldData, gen_data : Dictionary, generation_seed : int):
	var random : RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = generation_seed
	
	var rooms: Array = gen_data[ROOM_ARRAY_KEY] if gen_data.has(ROOM_ARRAY_KEY) else Array()
	rooms.append(_gen_starting_room_rect(data, random))
	
	gen_data[ROOM_ARRAY_KEY] = rooms


func _gen_starting_room_rect(data : WorldData, random : RandomNumberGenerator) -> Rect2:
	var value := Rect2()
	
	var p_x = random.randi_range(1, data.get_size_x() - 1 - single_tile_width)
	var p_z = random.randi_range(1, data.get_size_z() - 1 - single_tile_height)
	
	value = Rect2(p_x, p_z, single_tile_width, single_tile_height)
	return value


func _fill_map_data(data : WorldData, gen_data : Dictionary):
	var rooms : Array = gen_data.get(ROOM_ARRAY_KEY) as Array
	
	var starting_room := rooms[0] as Rect2
	data.fill_room_data(starting_room, RoomData.OriginalPurpose.LEVEL_STAIRCASE)
	data.player_spawn_position = starting_room.position + player_offset

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
