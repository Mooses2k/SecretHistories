extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

enum AstarType {
	EMPTY,
	ROOM,
	EDGE,
}

enum CorridorGenerationResults {
	FAILED,
	DOOR,
	GOAL,
}

#--- constants ------------------------------------------------------------------------------------

const GraphGenerator = preload("generate_room_graph.gd")

const MASK_EMPTY = 0b0000
const MASK_ROOM_TOP_LEFT = 0b0001
const MASK_ROOM_TOP_RIGHT = 0b0010
const MASK_ROOM_BOTTOM_RIGHT = 0b0100
const MASK_ROOM_BOTTOM_LEFT = 0b1000

const MASK_ROOM_NORTH = MASK_ROOM_TOP_LEFT | MASK_ROOM_TOP_RIGHT
const MASK_ROOM_EAST = MASK_ROOM_TOP_RIGHT | MASK_ROOM_BOTTOM_RIGHT
const MASK_ROOM_SOUTH = MASK_ROOM_BOTTOM_LEFT | MASK_ROOM_BOTTOM_RIGHT
const MASK_ROOM_WEST = MASK_ROOM_TOP_LEFT | MASK_ROOM_BOTTOM_LEFT
const MASK_FULL_ROOM = 0b1111

#--- public variables - order: export > normal var > onready --------------------------------------

export var existing_corridor_weight : float = 0.5
export var existing_room_weight : float = 2.0
export var room_edge_cost_multiplier : float = 1.5

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### GenerationStep Virtual Overrides --------------------------------------------------------------------

func _execute_step(data : WorldData, gen_data : Dictionary, _generation_seed : int):
	var graph = gen_data.get(GraphGenerator.CONNECTION_GRAPH_KEY, Dictionary()) as Dictionary
	var astar = generate_double_a_star_grid(data)
	for a in graph.keys():
		for b in graph[a]:
			generate_double_corridor(data, astar, a, b)
	pass

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func generate_double_a_star_grid(data : WorldData) -> AStar2D:
	var astar = ManhattanAStar2D.new()
	_add_weighted_points_to_astar_grid(data, astar)
	_connect_points_in_astar_grid(data, astar)
	return astar


func generate_double_corridor(data : WorldData, astar : AStar2D, a : int, b : int) -> void:
	var is_generating := true
	while is_generating:
		var results := _generate_corridor_until_first_door(data, astar, a, b)
		if results == CorridorGenerationResults.FAILED:
			is_generating = false
			push_error("Failed to build corridor between a:%s and b:%s"%[a, b])
			return
		else:
			var rooms := [
					data.get_cell_meta(a, data.CellMetaKeys.META_ROOM_DATA),
					data.get_cell_meta(b, data.CellMetaKeys.META_ROOM_DATA),
			]
			
			for room_value in rooms:
				var room := room_value as RoomData
				if not room.can_add_doorway():
					_disconnect_room_walls_from_grid(data, astar, room)
			
			if results == CorridorGenerationResults.GOAL:
				is_generating = false

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _add_weighted_points_to_astar_grid(data: WorldData, astar: AStar2D) -> void:
	for x in range(1, data.world_size_x - 1):
		for z in range(1, data.world_size_z - 1):
			var cells = [
				data.get_cell_index_from_int_position(x - 1, z - 1),
				data.get_cell_index_from_int_position(x, z - 1),
				data.get_cell_index_from_int_position(x, z),
				data.get_cell_index_from_int_position(x - 1, z),
			]
			
			var room_mask = _get_cell_mask(data, cells, data.CellType.ROOM)
			var point := Vector2(x, z)
			var weight := _get_weight_for(room_mask)
			if weight > 0:
				astar.add_point(cells[2], point, weight)


func _get_cell_mask(data : WorldData, cells : Array, value: int) -> int:
	var mask = MASK_EMPTY
	mask = mask | MASK_ROOM_TOP_LEFT * int(data.get_cell_type(cells[0]) == value)
	mask = mask | MASK_ROOM_TOP_RIGHT * int(data.get_cell_type(cells[1]) == value)
	mask = mask | MASK_ROOM_BOTTOM_RIGHT * int(data.get_cell_type(cells[2]) == value)
	mask = mask | MASK_ROOM_BOTTOM_LEFT * int(data.get_cell_type(cells[3]) == value)
	return mask


func _get_weight_for(room_mask: int) -> float:
	var weight = 1.0
	
	# fully outside of a room
	if room_mask == MASK_EMPTY:
		weight = 1.0
	# fully inside of a room
	elif room_mask == MASK_FULL_ROOM:
		weight = existing_room_weight
	# at the edge of a room
	elif (
			room_mask == MASK_ROOM_NORTH 
			or room_mask == MASK_ROOM_EAST 
			or room_mask == MASK_ROOM_SOUTH 
			or room_mask == MASK_ROOM_WEST
	):
		# high weight to make crossing the edge mostly perpendicular
		weight = room_edge_cost_multiplier * existing_room_weight
	# at the corner of one or more rooms (internal or external)
	else:
		weight = 0
	
	return weight


func _connect_points_in_astar_grid(data: WorldData, astar: AStar2D) -> void:
	for x in range(1, data.world_size_x-1):
		for z in range(1, data.world_size_z-1):
			var cell_index = data.get_cell_index_from_int_position(x, z)
			if not astar.has_point(cell_index):
				continue
			
			for direction in data.Direction.DIRECTION_MAX:
				var neighbour = data.get_neighbour_cell(cell_index, direction)
				if neighbour != -1 and astar.has_point(neighbour):
					astar.connect_points(cell_index, neighbour)


func _generate_corridor_until_first_door(data: WorldData, astar: AStar2D, a: int, b: int) -> int:
	var has_reached_b := CorridorGenerationResults.GOAL as int
	var path : PoolIntArray = astar.get_id_path(a, b)
	if not (path.size() > 0 and path[0] == a and path[-1] == b):
		print("a: %s (%s) | b: %s (%s) | path[0]: %s | path[-1]: %s"%[
				a, data.get_int_position_from_cell_index(a), 
				b, data.get_int_position_from_cell_index(b),
				path[0], path[-1]
		])
		return has_reached_b
	
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
		var mask_2x2 = _get_cell_mask(data, cells, data.CellType.ROOM)
		
		var astar_type := AstarType.EMPTY as int
		var is_new_door := true
		match mask_2x2:
			MASK_EMPTY:
				_set_cells(data, cells, [
						data.CellType.CORRIDOR, data.CellType.CORRIDOR, 
						data.CellType.CORRIDOR, data.CellType.CORRIDOR
				])
			MASK_ROOM_NORTH:
				_set_cells(data, cells, [
						data.CellType.ROOM, data.CellType.ROOM, 
						data.CellType.DOOR, data.CellType.DOOR
				])
				is_new_door = _set_doorways_meta(data, cells, data.Direction.NORTH)
				astar_type = AstarType.EDGE
			MASK_ROOM_EAST:
				_set_cells(data, cells, [
						data.CellType.DOOR, data.CellType.ROOM, 
						data.CellType.ROOM, data.CellType.DOOR
				])
				is_new_door = _set_doorways_meta(data, cells, data.Direction.EAST)
				astar_type = AstarType.EDGE
			MASK_ROOM_SOUTH:
				_set_cells(data, cells, [
						data.CellType.DOOR, data.CellType.DOOR, 
						data.CellType.ROOM, data.CellType.ROOM
				])
				is_new_door = _set_doorways_meta(data, cells, data.Direction.SOUTH)
				astar_type = AstarType.EDGE
			MASK_ROOM_WEST:
				_set_cells(data, cells, [
						data.CellType.ROOM, data.CellType.DOOR, 
						data.CellType.DOOR, data.CellType.ROOM]
				)
				is_new_door = _set_doorways_meta(data, cells, data.Direction.WEST)
				astar_type = AstarType.EDGE
			MASK_FULL_ROOM:
				astar_type = AstarType.ROOM
		
		if astar_type == AstarType.EDGE:
			if path[i] != b and is_new_door:
				has_reached_b = CorridorGenerationResults.DOOR
				break
		
		if not astar_type == AstarType.ROOM:
			astar.set_point_weight_scale(cells[2], existing_corridor_weight)
	
	return has_reached_b


func _set_cells(data : WorldData, cells : Array, values : Array):
	for i in cells.size():
		if values [i] > data.get_cell_type(cells[i]):
			data.set_cell_type(cells[i], values[i])


func _add_door_direction(data : WorldData, cell : int, value : int):
	if not data.has_cell_meta(cell, data.CellMetaKeys.META_DOOR_DIRECTIONS):
		data.set_cell_meta(cell, data.CellMetaKeys.META_DOOR_DIRECTIONS, Array())
	if not data.get_cell_meta(cell, data.CellMetaKeys.META_DOOR_DIRECTIONS).has(value):
		data.get_cell_meta(cell, data.CellMetaKeys.META_DOOR_DIRECTIONS).push_back(value)


func _set_doorways_meta(data: WorldData, cells: Array, direction: int) -> bool:
	var did_add_door := true
	if cells.empty():
		return false
	
	for cell in cells:
		if data.get_cell_type(cell) == data.CellType.ROOM:
			var room_data := data.get_cell_meta(cell, data.CellMetaKeys.META_ROOM_DATA) as RoomData
			var corridor_direction = data.direction_inverse(direction)
			if not room_data.has_doorway_on(cell, corridor_direction):
				room_data.set_doorway_cell(cell, corridor_direction)
			else:
				did_add_door = false
		elif data.get_cell_type(cell) == data.CellType.DOOR:
			_add_door_direction(data, cell, direction)
	
	return did_add_door


func _disconnect_room_walls_from_grid(data: WorldData, astar: AStar2D, room: RoomData) -> void:
	var doorway_cells := room.get_all_doorway_cells()
	for cell_index in room.cell_indexes:
		for direction in data.Direction.DIRECTION_MAX:
			if cell_index in doorway_cells:
				continue
			
			var neighbour_index := data.get_neighbour_cell(cell_index, direction)
			if neighbour_index != -1 and not neighbour_index in room.cell_indexes:
				if astar.are_points_connected(cell_index, neighbour_index):
					astar.disconnect_points(cell_index, neighbour_index)

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
