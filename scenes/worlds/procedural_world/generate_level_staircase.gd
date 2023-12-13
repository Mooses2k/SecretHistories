# Write your doc string for this file here
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

export var single_tile_width := 2
export var single_tile_height := 2
export var minimum_distance_between_staircases := 3
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
	
	var cells_pool := _get_pool_of_possible_cells(data)
	
	var entry_room := _gen_staircase_room_rect(data, random, cells_pool)
	data.fill_room_data(entry_room, RoomData.OriginalPurpose.UP_STAIRCASE)
	rooms.append(entry_room)
	
	if not gen_data[LAST_FLOOR_KEY]:
		cells_pool = _update_poll_of_possible_cells(data, cells_pool, entry_room)
		
		var exit_room := _gen_staircase_room_rect(data, random, cells_pool)
		data.fill_room_data(exit_room, RoomData.OriginalPurpose.DOWN_STAIRCASE)
		rooms.append(exit_room)
		var index := data.get_cell_index_from_int_position(
				exit_room.position.x, exit_room.position.y
		)
		var room_data := data.get_cell_meta(index, data.CellMetaKeys.META_ROOM_DATA) as RoomData
		for cell_index in room_data.cell_indexes:
			data.set_cell_meta(cell_index, data.CellMetaKeys.META_IS_DOWN_STAIRCASE, true)
	
	gen_data[ROOM_ARRAY_KEY] = rooms


func _gen_staircase_room_rect(
		data: WorldData, 
		random: RandomNumberGenerator, 
		cells_pool: Array
) -> Rect2:
	var value := Rect2()
	
	var random_index := random.randi_range(0, cells_pool.size()-1)
	var initial_position := data.get_int_position_from_cell_index(cells_pool[random_index])
	
	value = Rect2(initial_position[0], initial_position[1], single_tile_width, single_tile_height)
	return value


func _get_pool_of_possible_cells(data: WorldData) -> Array:
	var value := []
	# These are to make sure there is a margin of one tile on all sides of the board
	var min_x = 1
	var max_x = data.get_size_x() - 1 - single_tile_width
	var min_y = 1
	var max_y = data.get_size_z() - 1 - single_tile_height
	
	for x in range(min_x, max_x):
		for y in range(min_y, max_y):
			var can_fit_room := _can_fit_staircase_room(data, x, y)
			if can_fit_room:
				var cell_index = data.get_cell_index_from_int_position(x, y)
				value.append(cell_index)
	
	return value


func _update_poll_of_possible_cells(data: WorldData, cells_pool: Array, room: Rect2) -> Array:
	var value := []
	var range_x = range(room.position.x, room.end.x)
	var range_y = range(room.position.y, room.end.y)
	
	for x in range_x:
		for y in range_y:
			var cell_index := data.get_cell_index_from_int_position(x, y)
			if cell_index > -1:
				cells_pool.erase(cell_index)
	
	for index in range(cells_pool.size()-1, -1, -1):
		var cell_index := cells_pool[index] as int
		var position_array = data.get_int_position_from_cell_index(cell_index)
		if _can_fit_staircase_room(data, position_array[0], position_array[1]):
			value.append(cell_index)
	
	return value

func _can_fit_staircase_room(data: WorldData, initial_x: int, initial_y: int) -> bool:
	var value := true
	var max_size_x = (single_tile_width) + minimum_distance_between_staircases
	var max_size_y = (single_tile_height) + minimum_distance_between_staircases
	var offsets_x := range(-minimum_distance_between_staircases, max_size_x)
	var offsets_y := range(-minimum_distance_between_staircases, max_size_y)
	
	for offset_x in offsets_x:
		var x := int(initial_x + offset_x)
		for offset_y in offsets_y:
			var y := int(initial_y + offset_y)
			if data.is_inside_world_bounds(x, y):
				var cell_index = data.get_cell_index_from_int_position(x, y)
				value = data.is_cell_free(cell_index)
				if not value:
					break
		if not value:
			break
	
	return value

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
