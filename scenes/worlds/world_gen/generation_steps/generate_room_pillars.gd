extends GenerationStep


# An array of rect2 containing all the pillar room boundaries will be
# added to the gen_data by this step under the following key
const PILLAR_ROOMS_KEY = "pillar_rooms"

# marks rooms as being pillar rooms
# a pillar room is any rectangular room that has all dimensins as a multiple of 2
# these rooms will be populated with pillars and use 2-wide tiles

export var pillar_tile : int = -1
export var min_room_dimension : int = 4 # changing to 4 puts pillars in any room with 4+ on a side


# Override this function
func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	var pillar_rooms : Array = Array()
	# Iterates through all of the rooms, ignoring any that has one dimension smaller
	# than the minimum specified on `min_room_dimension`
	# for each cell on a room that passes the dimension test, the 4x4 grid around
	# the potential pillar is checked to verify that it contains only room cells
	# and the area immediatelly around the pillar is also checked for other
	# pillars, to prevent placing pillars too close to each other
	
	var rooms := data.get_all_rooms()
	for value in rooms:
		var room_data := value as RoomData
		var room_rect := room_data.rect2
		
		# Validity Checks
		# Check that room clears the minimum size requirement
		if not room_data.is_min_dimension_greater_or_equal_to(min_room_dimension):
			continue
		
		# Check that the room dimensions are even
		if int(room_rect.size.x) % 2 != 0 and int(room_rect.size.y) % 2 != 0:
			continue
		
		# Check that the room fills all cells of the rectangle
		if room_rect.size.x*room_rect.size.y != room_data.cell_indexes.size():
			continue
		
		# Checks that all walls and doors on the room are aligned to even spacing,
		# To allow placing double wide tiles
		var walls_even_aligned = true
		# Check NORTH and SOUTH walls for odd offsets
		for i in room_rect.size.x:
			# North
			var cell = data.get_cell_index_from_int_position(room_rect.position.x + i, room_rect.position.y)
			var wall_type = data.get_wall_type(cell, data.Direction.NORTH)
			# check even cells
			if i % 2 == 0 and not (wall_type == data.EdgeType.WALL or wall_type == data.EdgeType.HALFDOOR_P):
				walls_even_aligned = false
				break
			# check odd cells
			if i % 2 == 1 and not (wall_type == data.EdgeType.WALL or wall_type == data.EdgeType.HALFDOOR_N):
				walls_even_aligned = false
				break
			
			# South
			cell = data.get_cell_index_from_int_position(room_rect.position.x + i, room_rect.position.y + room_rect.size.y - 1)
			wall_type = data.get_wall_type(cell, data.Direction.SOUTH)
			# check even cells
			if i % 2 == 0 and not (wall_type == data.EdgeType.WALL or wall_type == data.EdgeType.HALFDOOR_P):
				walls_even_aligned = false
				break
			# check odd cells
			if i % 2 == 1 and not (wall_type == data.EdgeType.WALL or wall_type == data.EdgeType.HALFDOOR_N):
				walls_even_aligned = false
				break
		
		# Check WEST and EAST walls for odd offsets
		for i in room_rect.size.y:
			# West
			var cell = data.get_cell_index_from_int_position(room_rect.position.x, room_rect.position.y + i)
			var wall_type = data.get_wall_type(cell, data.Direction.WEST)
			# check even cells
			if i % 2 == 0 and not (wall_type == data.EdgeType.WALL or wall_type == data.EdgeType.HALFDOOR_P):
				walls_even_aligned = false
				break
			# check odd cells
			if i % 2 == 1 and not (wall_type == data.EdgeType.WALL or wall_type == data.EdgeType.HALFDOOR_N):
				walls_even_aligned = false
				break
			
			# East
			cell = data.get_cell_index_from_int_position(room_rect.position.x + room_rect.size.x - 1, room_rect.position.y + i)
			wall_type = data.get_wall_type(cell, data.Direction.EAST)
			# check even cells
			if i % 2 == 0 and not (wall_type == data.EdgeType.WALL or wall_type == data.EdgeType.HALFDOOR_P):
				walls_even_aligned = false
				break
			# check odd cells
			if i % 2 == 1 and not (wall_type == data.EdgeType.WALL or wall_type == data.EdgeType.HALFDOOR_N):
				walls_even_aligned = false
				break
		
		if not walls_even_aligned:
			continue
		
		#Room has passed all checks, consider it a pillar room
		room_data.has_pillars = true
		for cell in room_data.cell_indexes:
			data.set_cell_meta(cell, data.CellMetaKeys.META_PILLAR_ROOM, true)
		
		pillar_rooms.push_back(room_rect)
	
	print("pillar rooms: %s" % [pillar_rooms])
	if gen_data.has(PILLAR_ROOMS_KEY):
		printerr("Generation data already contains pillar room data")
		return
	gen_data[PILLAR_ROOMS_KEY] = pillar_rooms
