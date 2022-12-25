extends GenerationStep


export var existing_corridor_weight : float = 0.5
export var existing_room_weight : float = 2.0
export var room_edge_cost_multiplier : float = 1.5

const GraphGenerator = preload("generate_room_graph.gd")


# Override this function
func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	var graph = gen_data.get(GraphGenerator.CONNECTION_GRAPH_KEY, Dictionary()) as Dictionary
	var astar = generate_double_a_star_grid(data)
	for a in graph.keys():
		for b in graph[a]:
			generate_double_corridor(data, astar, a, b)
	pass


func get_cell_mask(data : WorldData, cells : Array, value : int) -> int:
	var mask = 0b0000
	mask = mask | 0b0001*int(data.get_cell_type(cells[0]) == value)
	mask = mask | 0b0010*int(data.get_cell_type(cells[1]) == value)
	mask = mask | 0b0100*int(data.get_cell_type(cells[2]) == value)
	mask = mask | 0b1000*int(data.get_cell_type(cells[3]) == value)
	return mask


func generate_double_a_star_grid(data : WorldData) -> AStar2D:
	var astar = ManhattanAStar2D.new()
	for x in range(2, data.world_size_x - 1):
		for z in range(2, data.world_size_z - 1):
			var cells = [
				data.get_cell_index_from_int_position(x - 1, z - 1),
				data.get_cell_index_from_int_position(x, z - 1),
				data.get_cell_index_from_int_position(x, z),
				data.get_cell_index_from_int_position(x - 1, z),
			]
			var room_mask = get_cell_mask(data, cells, data.CellType.ROOM)
			var p : Vector2 = Vector2(x, z)
			
			var w = 1.0
			# fully outside of a room
			if room_mask == 0b0000:
				w = 1.0
			# fully inside of a room
			elif room_mask == 0b1111:
				w = existing_room_weight
			# at the edge of a room
			elif room_mask == 0b0011 or room_mask == 0b0110 or room_mask == 0b1100 or room_mask == 0b1001:
				# high weight to make crossing the edge mostly perpendicular
				w = room_edge_cost_multiplier*existing_room_weight
			# at the corner of one or more rooms (internal or external)
			else:
				# don't add corner points
				continue
			astar.add_point(cells[2], p, w)
	for x in range(1, data.world_size_x-1):
		for z in range(1, data.world_size_z-1):
			var i = data.get_cell_index_from_int_position(x, z)
			if not astar.has_point(i):
				continue
			if x != data.world_size_x - 1:
				var e = data.get_neighbour_cell(i, data.Direction.EAST)
				if astar.has_point(e):
					astar.connect_points(i, e)
			if x != 1:
				var w = data.get_neighbour_cell(i, data.Direction.WEST)
				if astar.has_point(w):
					astar.connect_points(i, w)
			if z != data.world_size_z - 1:
				var s = data.get_neighbour_cell(i, data.Direction.SOUTH)
				if astar.has_point(s):
					astar.connect_points(i, s)
			if z != 1:
				var n = data.get_neighbour_cell(i, data.Direction.NORTH)
				if astar.has_point(n):
					astar.connect_points(i, n)
	return astar


func set_cells(data : WorldData, cells : Array, values : Array):
	for i in cells.size():
		if values [i] > data.get_cell_type(cells[i]):
			data.set_cell_type(cells[i], values[i])


func add_door_direction(data : WorldData, cell : int, value : int):
	if not data.get_cell_meta(cell) is Array:
		data.set_cell_meta(cell, Array())
	if not data.get_cell_meta(cell).has(value):
		data.get_cell_meta(cell).push_back(value)


func generate_double_corridor(data : WorldData, astar : AStar2D, a : int, b : int) -> bool:
	var path : PoolIntArray = astar.get_id_path(a, b)
	if not (path.size() > 0 and path[0] == a and path[-1] == b):
		print(a)
		print(data.get_int_position_from_cell_index(a))
		print(b)
		print(data.get_int_position_from_cell_index(b))
		return false
	for i in path.size():
		var coords = data.get_int_position_from_cell_index(path[i])
		var x = coords[0]
		var z = coords[1]
		var cells = [
				data.get_cell_index_from_int_position(x - 1, z - 1),
				data.get_cell_index_from_int_position(x, z - 1),
				data.get_cell_index_from_int_position(x, z),
				data.get_cell_index_from_int_position(x - 1, z),
			]
		# room mask as 3210 (clockwise order from lower bit)
		var rooms = get_cell_mask(data, cells, data.CellType.ROOM)
		
		var is_edge = false
		var is_room = false
		match rooms:
			0b0000:
				set_cells(data, cells, [data.CellType.CORRIDOR, data.CellType.CORRIDOR, data.CellType.CORRIDOR, data.CellType.CORRIDOR])
			0b0011:
				set_cells(data, cells, [data.CellType.ROOM, data.CellType.ROOM, data.CellType.DOOR, data.CellType.DOOR])
				add_door_direction(data, cells[2], data.Direction.NORTH)
				add_door_direction(data, cells[3], data.Direction.NORTH)
				is_edge = true
			0b0110:
				set_cells(data, cells, [data.CellType.DOOR, data.CellType.ROOM, data.CellType.ROOM, data.CellType.DOOR])
				add_door_direction(data, cells[0], data.Direction.EAST)
				add_door_direction(data, cells[3], data.Direction.EAST)
				is_edge = true
			0b1100:
				set_cells(data, cells, [data.CellType.DOOR, data.CellType.DOOR, data.CellType.ROOM, data.CellType.ROOM])
				add_door_direction(data, cells[0], data.Direction.SOUTH)
				add_door_direction(data, cells[1], data.Direction.SOUTH)
				is_edge = true
			0b1001:
				set_cells(data, cells, [data.CellType.ROOM, data.CellType.DOOR, data.CellType.DOOR, data.CellType.ROOM])
				add_door_direction(data, cells[1], data.Direction.WEST)
				add_door_direction(data, cells[2], data.Direction.WEST)
				is_edge = true
			0b1111:
				is_room = true
		if not is_room:
			astar.set_point_weight_scale(cells[2], existing_corridor_weight)
	return true
