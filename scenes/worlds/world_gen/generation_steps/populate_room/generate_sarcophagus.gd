# Write your doc string for this file here
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const Sarcophagus = preload("res://scenes/objects/large_objects/sarcophagi/sarcophagus.gd")

#--- public variables - order: export > normal var > onready --------------------------------------

export(String, FILE, "*.tscn") var sarco_scene_path := \
	"res://scenes/objects/large_objects/sarcophagi/sarcophagus.tscn"

export var sarco_tile_size := Vector2(2,2)
export var min_size_for_middle_sarco := 6
# Angle in degrees that the sarcos have to be rotated when spawning in each direction
export(float, -360.0, 360.0, 1.0) var rotation_north := 0.0
export(float, -360.0, 360.0, 1.0) var rotation_east := 270.0
export(float, -360.0, 360.0, 1.0) var rotation_south := 180.0
export(float, -360.0, 360.0, 1.0) var rotation_west := 90.0

#--- private variables - order: export > normal var > onready -------------------------------------

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
	for c_value in crypt_rooms:
		var crypt := c_value as RoomData
		var walls_data := RoomWalls.new()
		walls_data.init_from_room(data, crypt, sarco_tile_size)
		print("Crypt Walls: %s"%[walls_data])
		_spawn_sarcos_on_walls(data, walls_data)
		
		if crypt.is_min_dimension_greater_or_equal_to(min_size_for_middle_sarco):
			_spawn_middle_sarco(data, crypt)


func _spawn_sarcos_on_walls(data: WorldData, walls_data: RoomWalls) -> void:
	for direction in walls_data.main_walls:
		var sarco_rotation := _get_sarco_rotation(direction)
		var segments := walls_data.get_sanitized_segments_for(data, direction, sarco_tile_size)
		var sarco_offset := _get_sarco_offset(direction) * data.CELL_SIZE
		for value in segments:
			var segment := value as Array
			var surplus_cells := segment.size() % int(sarco_tile_size.x)
			if surplus_cells == 0:
				for index in range(0, segment.size(), sarco_tile_size.x):
					var sarco_cells = segment.slice(index, index + sarco_tile_size.x - 1)
					_set_sarco_spawn_data(data, sarco_cells, sarco_rotation, sarco_offset)
			else:
				sarco_offset += Vector3(surplus_cells * data.CELL_SIZE / 2.0, 0, 0)
				_set_sarco_spawn_data(data, segment, sarco_rotation, sarco_offset)


func _set_sarco_spawn_data(
		data: WorldData, sarco_cells: Array, sarco_rotation: float, sarco_offset := Vector3.ZERO
) -> void:
	var spawn_data := SpawnData.new()
	spawn_data.scene_path = sarco_scene_path
	var spawn_position = (
			data.get_local_cell_position(sarco_cells[0])
			+ sarco_offset.rotated(Vector3.UP, sarco_rotation) 
	)
	spawn_data.set_y_rotation(sarco_rotation)
	spawn_data.set_position_in_cell(spawn_position)
	
	var lid_type := Sarcophagus.get_random_lid_type(_rng)
	spawn_data.set_custom_property("current_lid", lid_type)
	
	for cell_index in sarco_cells:
		data.set_object_spawn_data_to_cell(cell_index, spawn_data)


func _spawn_middle_sarco(data: WorldData, crypt: RoomData) -> void:
	pass


func _get_sarco_rotation(direction: int) -> float:
	var value := rotation_north
	
	match direction:
		WorldData.Direction.EAST:
			value = deg2rad(rotation_east)
		WorldData.Direction.SOUTH:
			value = deg2rad(rotation_south)
		WorldData.Direction.WEST:
			value = deg2rad(rotation_west)
	
	return value


func _get_sarco_offset(direction: int) -> Vector3:
	var value := Vector3.ZERO
	
	match direction:
		WorldData.Direction.EAST:
			value = Vector3(0, 0, -1)
		WorldData.Direction.SOUTH:
			value = Vector3(-1 * sarco_tile_size.x, 0, -1)
		WorldData.Direction.WEST:
			value = Vector3(-1 * sarco_tile_size.x, 0, 0)
	
	return value

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

class RoomWalls extends Reference:
	# value is an array of array of cell indexes. Each cell index array has a group of 
	# consecutive cells in the same wall, unbroken by doors.
	var cells := {
			WorldData.Direction.NORTH: [],
			WorldData.Direction.EAST: [],
			WorldData.Direction.SOUTH: [],
			WorldData.Direction.WEST: [],
	}
	
	# Array of Directions. See 
	var main_walls := []
	
	func _to_string() -> String:
		var msg := "RoomWalls:"
		
		for direction in cells:
			msg += "\n %s: %s"%[WorldData.Direction.keys()[direction], cells[direction]]
		
		msg += "\n main walls:"
		for direction in main_walls:
			msg += "\n %s"%[WorldData.Direction.keys()[direction]]
		
		return msg
	
	
	func init_from_room(world_data: WorldData, crypt: RoomData, sarco_tile_size: Vector2) -> void:
		_handle_wall_cells(world_data, crypt, sarco_tile_size.x)
		_handle_main_wall(world_data, crypt)
	
	
	# Returns an array of "segments" (arrays of consecutive cell_index) that can fit the whole
	# sarco size. If there is no "segment" that can fit the sarcophagus length and width,
	# returns an empty array.
	func get_sanitized_segments_for(
			data: WorldData, wall_direction: int, sarco_tile_size: Vector2
	) -> Array:
		var sanitized_segments := []
		var free_segments := []
		
		var width_direction := data.direction_inverse(wall_direction)
		for value in cells[wall_direction]:
			var raw_segment := value.duplicate() as Array
			var indexes_to_remove := []
			for index in raw_segment.size():
				var current_cell := raw_segment[index] as int
				var is_free := data.is_cell_free(current_cell)
				for _index in sarco_tile_size.y - 1:
					if is_free:
						current_cell = data.get_neighbour_cell(current_cell, width_direction)
						is_free = data.is_cell_free(current_cell)
				
				if not is_free:
					indexes_to_remove.append(index)
			
			if not indexes_to_remove.empty():
				for r_index in range(indexes_to_remove.size()-1, -1, -1):
					raw_segment.remove(indexes_to_remove[r_index])
				
				if raw_segment.size() >= sarco_tile_size.x:
					free_segments.append(raw_segment)
			else:
				free_segments.append(raw_segment)
		
		for value in free_segments:
			var segment := value as Array
			var sarcos_per_segment := segment.size() / int(sarco_tile_size.x)
			var surplus_tiles := segment.size() % int(sarco_tile_size.x)
			var centralized_and_fit_segments := _handle_segments_size(
					surplus_tiles, sarcos_per_segment, segment, sarco_tile_size
			)
			sanitized_segments.append_array(centralized_and_fit_segments)
		
		return sanitized_segments
	
	
	# Analyzes the room and find all cell indexes according to wall direction they're on.
	# Then only store the groups of consecutive cell index that are bigger than 
	# the length of the sarco.
	func _handle_wall_cells(world_data: WorldData, crypt: RoomData, sarco_length: int) -> void:
		var possible_cells := {
			WorldData.Direction.NORTH: [],
			WorldData.Direction.EAST: [],
			WorldData.Direction.SOUTH: [],
			WorldData.Direction.WEST: [],
		}
		
		for cell_index in crypt.cell_indexes:
			for direction in WorldData.Direction.values():
				if direction == WorldData.Direction.DIRECTION_MAX:
					continue
				
				var edge_type := world_data.get_wall_type(cell_index, direction)
				match edge_type:
					WorldData.EdgeType.WALL:
						possible_cells[direction].append(cell_index)
		
		for direction in possible_cells:
			if possible_cells[direction].empty():
				continue
			
			var neighbour_cells := []
			var length_direction := world_data.direction_rotate_cw(direction)
			if direction == WorldData.Direction.SOUTH or direction == WorldData.Direction.WEST:
				length_direction = world_data.direction_rotate_ccw(direction)
			
			for index in range(1, possible_cells[direction].size()):
				var previous_cell := possible_cells[direction][index - 1] as int
				var current_cell := possible_cells[direction][index] as int
				if current_cell == world_data.get_neighbour_cell(previous_cell, length_direction):
					if neighbour_cells.empty():
						neighbour_cells.append(previous_cell)
					neighbour_cells.append(current_cell)
				else:
					if neighbour_cells.size() >= sarco_length:
						cells[direction].append(neighbour_cells.duplicate())
					neighbour_cells.clear()
			
			if neighbour_cells.size() >= sarco_length:
				cells[direction].append(neighbour_cells.duplicate())
	
	
	# Sets main_walls according to doorways in crypt. If cript has:
	# - one doorway: set the opposing wall as main
	# - two doorways: if they are parallel, like NORTH and SOUTH, sets the main walls to the 
	#                 perpendicular axis, so WEST and EAST. If not then opposes the first wall.
	# - three doorways: sets the wall with no doors as main.
	# - four doorways: no main wall.
	func _handle_main_wall(world_data: WorldData, crypt: RoomData) -> void:
		var doorway_walls := crypt.get_doorway_directions()
		if doorway_walls.size() == 1:
			var opposing_wall := world_data.direction_inverse(doorway_walls[0])
			main_walls.append(opposing_wall)
		elif doorway_walls.size() == 2:
			var doorway1_direction = doorway_walls[0]
			var doorway2_direction = doorway_walls[1]
			if world_data.direction_inverse(doorway1_direction) == doorway2_direction:
				for direction in doorway_walls:
					var perpendicular_direction := world_data.direction_rotate_cw(direction)
					main_walls.append(perpendicular_direction)
			else:
				var opposing_wall := world_data.direction_inverse(doorway1_direction)
				main_walls.append(opposing_wall)
		elif doorway_walls.size() == 3:
			for direction in cells:
				if not doorway_walls.has(direction):
					main_walls.append(direction)
					break
	
	
	# Returns an Array of segments where either the segments will fit the number of sarcos and be
	# centralized in the total wall segment, or centralized with one tile of distance between them 
	# for odd numbered walls with even numbered sarcos, or will be one tile lengthier than the 
	# sarco so that spawning knows to offset it so it's centered in sarco_tile_size.x + 1, and for
	# everything else that comes after, the cells this sarco occupies will be considered one more
	# in length than normal.
	func _handle_segments_size(
			surplus_tiles: int, sarcos_per_segment: int, segment: Array, sarco_tile_size: Vector2
	) -> Array:
		var final_segments := []
		
		if surplus_tiles == 0:
			final_segments.append(segment)
		elif surplus_tiles % 2 == 0:
			for _index in sarcos_per_segment:
				segment.pop_back()
				segment.pop_front()
			final_segments.append(segment)
		elif surplus_tiles % 2 == 1:
			if sarcos_per_segment % 2 == 0:
				var middle_index := segment.size() / 2
				final_segments.append(segment.slice(0, middle_index-1))
				final_segments.append(segment.slice(middle_index+1, segment.size()-1))
			else:
				if sarcos_per_segment > 1:
					surplus_tiles += sarco_tile_size.x
					sarcos_per_segment -= 1
					final_segments = _handle_segments_size(
						surplus_tiles, sarcos_per_segment, segment, sarco_tile_size
					)
				elif surplus_tiles > 1:
					surplus_tiles -= 1
					final_segments = _handle_segments_size(
						surplus_tiles, sarcos_per_segment, segment, sarco_tile_size
					)
				elif surplus_tiles == 1:
					final_segments.append(segment)
		
		return final_segments
