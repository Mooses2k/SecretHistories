extends GenerationStep


export var pillar_tile : int = -1
export var min_room_dimension : int = 4


# Override this function
func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	var room_index : PoolIntArray = PoolIntArray()
	var room_rects : Array = Array()
	var cells_in_room : Array = Array()
	room_index.resize(data.cell_count)
	room_index.fill(0)
	var current_room_index = 0
	
	# Iterates through all the cells, fiding connected ROOM cells.
	# Each cluster of connected ROOM cells is considered a separate room
	# and given a room index (the room index of each cell is stored on the
	# room_index array). The AABB of each room is also calculated and stored
	# on the room_rects array as a Rect2, and an array of the cells belonging
	# to each room is stored on the cells_in_room array
	for i in data.cell_count:
		if room_index[i] == 0 and data.get_cell_type(i) == data.CellType.ROOM:
			var queue = Array()
			queue.push_back(i)
			var queue_index = 0
			current_room_index += 1
			room_index[i] = current_room_index
			var cell_pos_int = data.get_int_position_from_cell_index(i)
			var room_rect = Rect2(cell_pos_int[0], cell_pos_int[1], 1, 1)
			
			while queue_index != queue.size():
				var cell = queue[queue_index]
				cell_pos_int = data.get_int_position_from_cell_index(cell)
				var cell_rect = Rect2(cell_pos_int[0], cell_pos_int[1], 1, 1)
				room_rect = room_rect.merge(cell_rect)
				for dir in data.Direction.DIRECTION_MAX:
					var neighbour = data.get_neighbour_cell(cell, dir)
					var neighbour_type = data.get_cell_type(neighbour)
					if room_index[neighbour] == 0 and neighbour_type == data.CellType.ROOM:
						room_index[neighbour] = current_room_index
						queue.push_back(neighbour)
				queue_index += 1
			room_rects.push_back(room_rect)
			cells_in_room.push_back(queue)
	
	# Iterates through all of the rooms, ignoring any that has one dimension smaller
	# than the minimum specified on `min_room_dimension`
	# for each cell on a room that passes the dimension test, the 4x4 grid around
	# the potential pillar is checked to verify that it contains only room cells
	# and the area immediatelly around the pillar is also checked for other
	# pillars, to prevent placing pillars too close to each other
	for room in room_rects.size():
		var room_rect = room_rects[room] as Rect2
		if room_rect.size.x < min_room_dimension or room_rect.size.y < min_room_dimension:
			continue
		var cells_with_pillar : Dictionary = Dictionary()
		for cell in cells_in_room[room]:
			var cell_coords = data.get_int_position_from_cell_index(cell)
			var cell_x = cell_coords[0]
			var cell_z = cell_coords[1]
			var should_place = true
			
			# This loop checks the 4x4 area around the pillar for all room cells
			####
			####
			##O#
			####
			for dx in range(-2, 2):
				for dz in range(-2, 2):
					var other_cell = data.get_cell_index_from_int_position(cell_x + dx, cell_z + dz)
					if other_cell < 0 or data.get_cell_type(other_cell) != data.CellType.ROOM:
						should_place = false
						break
				if not should_place:
					break
			# this loop checks the immediate neighbourhood for any other pillars
			###
			#O#
			###
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					var other_cell = data.get_cell_index_from_int_position(cell_x + dx, cell_z + dz)
					if other_cell < 0 or cells_with_pillar.has(other_cell):
						should_place = false
						break
				if not should_place:
					break
			if should_place:
				data.set_pillar(cell, pillar_tile, 0.3)
				cells_with_pillar[cell] = true
					
	pass
