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

const RoomGraphViz = preload("res://utils/debug_scenes/room_graph_viz.gd")
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

export var _path_graph_viz := NodePath()
export var _stop_at_corridor_count := -1

onready var _room_graph_viz := get_node_or_null(_path_graph_viz) as RoomGraphViz

### -----------------------------------------------------------------------------------------------


### GenerationStep Virtual Overrides --------------------------------------------------------------------

func _execute_step(data : WorldData, gen_data : Dictionary, _generation_seed : int):
	var graph = gen_data.get(GraphGenerator.CONNECTION_GRAPH_KEY, Dictionary()) as Dictionary
	var astar = generate_double_a_star_grid(data)
	var count := 0
	for from_index in graph.keys():
		for to_index in graph[from_index]:
			print("generating corridoer from %s to %s"%[from_index, to_index])
			generate_double_corridor(data, astar, from_index, to_index)
			
			# This is here just to help debug by being able to stop at any corridor
			if OS.has_feature("editor"):
				count += 1
				if count-1 == _stop_at_corridor_count:
					break
		
		# This is here just to help debug by being able to stop at any corridor
		if OS.has_feature("editor"):
			if count-1 == _stop_at_corridor_count:
				break
	
	if is_instance_valid(_room_graph_viz):
		_room_graph_viz.astar = astar

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func generate_double_a_star_grid(data : WorldData) -> AStar2D:
	var astar = ManhattanAStar2D.new()
	_add_weighted_points_to_astar_grid(data, astar)
	_connect_points_in_astar_grid(data, astar)
	return astar


func generate_double_corridor(
		data: WorldData, 
		astar: AStar2D, 
		from_index: int, 
		to_index: int
) -> void:
	var is_generating := true
	while is_generating:
		var results := _generate_corridor_until_first_door(data, astar, from_index, to_index)
		if results.status == CorridorGenerationResults.FAILED:
			is_generating = false
			push_error("Failed to build corridor from:%s to:%s"%[from_index, to_index])
			return
		else:
			var door_room_index := to_index
			if results.status == CorridorGenerationResults.DOOR:
				# This index is wrong, it's not an index to a room, maybe to a door?
				door_room_index = results.door_room_index
			
			var rooms := [
					data.get_cell_meta(from_index, data.CellMetaKeys.META_ROOM_DATA),
					data.get_cell_meta(door_room_index, data.CellMetaKeys.META_ROOM_DATA),
			]
			
			for room_value in rooms:
				var room := room_value as RoomData
				if not room.can_add_doorway():
					_disconnect_room_walls_from_grid(data, astar, room)
			
			if results.status == CorridorGenerationResults.GOAL:
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


func _generate_corridor_until_first_door(
		data: WorldData, 
		astar: AStar2D, 
		from_index: int, 
		to_index: int
) -> Dictionary:
	var results := {
		status = CorridorGenerationResults.GOAL,
		door_room_index = -1
	}
	var path : PoolIntArray = astar.get_id_path(from_index, to_index)
	if not (path.size() > 0 and path[0] == from_index and path[-1] == to_index):
		print("a: %s (%s) | b: %s (%s) | path[0]: %s | path[-1]: %s"%[
				from_index, data.get_int_position_from_cell_index(from_index), 
				to_index, data.get_int_position_from_cell_index(to_index),
				path[0], path[-1]
		])
		results.status = CorridorGenerationResults.FAILED
		return results
	
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
				results.door_room_index = cells[0]
				astar_type = AstarType.EDGE
			MASK_ROOM_EAST:
				_set_cells(data, cells, [
						data.CellType.DOOR, data.CellType.ROOM, 
						data.CellType.ROOM, data.CellType.DOOR
				])
				is_new_door = _set_doorways_meta(data, cells, data.Direction.EAST)
				results.door_room_index = cells[1]
				astar_type = AstarType.EDGE
			MASK_ROOM_SOUTH:
				_set_cells(data, cells, [
						data.CellType.DOOR, data.CellType.DOOR, 
						data.CellType.ROOM, data.CellType.ROOM
				])
				is_new_door = _set_doorways_meta(data, cells, data.Direction.SOUTH)
				results.door_room_index = cells[2]
				astar_type = AstarType.EDGE
			MASK_ROOM_WEST:
				_set_cells(data, cells, [
						data.CellType.ROOM, data.CellType.DOOR, 
						data.CellType.DOOR, data.CellType.ROOM]
				)
				is_new_door = _set_doorways_meta(data, cells, data.Direction.WEST)
				results.door_room_index = cells[0]
				astar_type = AstarType.EDGE
			MASK_FULL_ROOM:
				astar_type = AstarType.ROOM
		
		if astar_type == AstarType.EDGE:
			if path[i] != to_index and is_new_door:
				results.status = CorridorGenerationResults.DOOR
				break
		
		astar.set_point_weight_scale(cells[2], existing_corridor_weight)
	
	return results


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
			var neighbour_index := data.get_neighbour_cell(cell_index, direction)
			var is_door: bool = data.get_cell_type(neighbour_index) == data.CellType.DOOR
			if neighbour_index != -1 and not neighbour_index in room.cell_indexes and not is_door:
				if astar.are_points_connected(cell_index, neighbour_index):
					astar.disconnect_points(cell_index, neighbour_index)

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
