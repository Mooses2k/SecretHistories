# Write your doc string for this file here
tool
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

#--- private variables - order: export > normal var > onready -------------------------------------

var _force_lid := -1
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
		walls_data.init_from_room(data, crypt, sarco_tile_size, _rng)
		print("Crypt Walls: %s"%[walls_data])
		
		for direction in walls_data.main_walls:
			_spawn_sarcos_in_wall_segments(data, walls_data, direction)
		
		for direction in walls_data.cells:
			if direction in walls_data.main_walls:
				continue
			_spawn_sarcos_in_wall_segments(data, walls_data, direction)
			
		if crypt.is_min_dimension_greater_or_equal_to(min_size_for_middle_sarco):
			_spawn_middle_sarco(data, crypt)


func _spawn_sarcos_in_wall_segments(
		data: WorldData, walls_data: RoomWalls, direction: int
) -> void:
	var segments := walls_data.get_sanitized_segments_for(data, direction, sarco_tile_size)
	for value in segments:
		var segment := value as Array
		var surplus_cells := segment.size() % int(sarco_tile_size.x)
		if surplus_cells == 0:
			for index in range(0, segment.size(), sarco_tile_size.x):
				var slice = segment.slice(index, index + sarco_tile_size.x - 1)
				var sarco_cells := _get_all_cells_for_sarco(data, slice, direction)
				_set_sarco_spawn_data(data, sarco_cells, direction)
		else:
			var sarco_cells := _get_all_cells_for_sarco(data, segment, direction)
			var sarco_offset := _get_sarco_offset(direction, surplus_cells) * data.CELL_SIZE
			_set_sarco_spawn_data(data, sarco_cells, direction, sarco_offset)


func _get_all_cells_for_sarco(data: WorldData, segment: Array, direction: int) -> Array:
	var width_direction := data.direction_inverse(direction)
	var sarco_cells := []
	
	for cell_index in segment:
		sarco_cells.append(cell_index)
		for _width in sarco_tile_size.y - 1:
			cell_index = data.get_neighbour_cell(cell_index, width_direction)
			sarco_cells.append(cell_index)
	
	return sarco_cells


func _spawn_middle_sarco(data: WorldData, crypt: RoomData) -> void:
	pass


func _set_sarco_spawn_data(
		data: WorldData, sarco_cells: Array, wall_direction: float, sarco_offset := Vector3.ZERO
) -> void:
	var spawn_data := SpawnData.new()
	spawn_data.scene_path = sarco_scene_path
	
	var spawn_position = (
			data.get_local_cell_position(sarco_cells[0])
			+ sarco_offset
	)
	spawn_data.set_position_in_cell(spawn_position)
	
	var lid_type := Sarcophagus.get_random_lid_type(_rng)
	if _force_lid != -1:
		lid_type = _force_lid
	spawn_data.set_custom_property("current_lid", lid_type)
	spawn_data.set_custom_property("wall_direction", wall_direction)
	
	for cell_index in sarco_cells:
		data.set_object_spawn_data_to_cell(cell_index, spawn_data)


func _get_sarco_offset(direction: int, surplus_cells := 0) -> Vector3:
	var value := Vector3.ZERO
	
	var center_offset := surplus_cells / 2.0
	match direction:
		WorldData.Direction.NORTH, WorldData.Direction.SOUTH:
			value = Vector3(center_offset, 0, 0)
		WorldData.Direction.EAST, WorldData.Direction.WEST:
			value = Vector3(0, 0, center_offset)
	
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
	
	var _rng := RandomNumberGenerator.new()
	
	func _to_string() -> String:
		var msg := "RoomWalls:"
		
		for direction in cells:
			msg += "\n %s: %s"%[WorldData.Direction.keys()[direction], cells[direction]]
		
		msg += "\n main walls:"
		for direction in main_walls:
			msg += "\n %s"%[WorldData.Direction.keys()[direction]]
		
		return msg
	
	
	func init_from_room(
			world_data: WorldData, 
			crypt: RoomData, 
			sarco_tile_size: Vector2, 
			rng: RandomNumberGenerator
	) -> void:
		_rng = rng
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
			if crypt.has_doorway_on(cell_index):
				continue
			
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
	
	
	# Sets main_walls according to doorways in crypt, and exclude doorway walls. If crypt has:
	# - one doorway: set the opposing wall as main
	# - two doorways: if they are parallel, like NORTH and SOUTH, sets the main walls to the 
	#                 perpendicular axis, so WEST and EAST. If not then chooses the biggest wall
	#				  as main.
	# - three doorways: sets the wall with no doors as main.
	# - four doorways: no main wall, excludes no wall, let's sarco's spawn whetever there is space.
	func _handle_main_wall(world_data: WorldData, crypt: RoomData) -> void:
		var doorway_walls := crypt.get_doorway_directions()
		if doorway_walls.size() == 1:
			var opposing_wall := world_data.direction_inverse(doorway_walls[0])
			main_walls.append(opposing_wall)
			cells[doorway_walls[0]].clear()
		elif doorway_walls.size() == 2:
			var doorway1_direction = doorway_walls[0]
			var doorway2_direction = doorway_walls[1]
			
			if world_data.direction_inverse(doorway1_direction) == doorway2_direction:
				for direction in doorway_walls:
					var perpendicular_direction := world_data.direction_rotate_cw(direction)
					main_walls.append(perpendicular_direction)
			else:
				var opposing_walls := [
						world_data.direction_inverse(doorway1_direction),
						world_data.direction_inverse(doorway2_direction),
				]
				
				var total_sizes := {}
				for direction in opposing_walls:
					if not direction in total_sizes:
						total_sizes[direction] = 0
					for array in cells[direction]:
						var segment := array as Array
						total_sizes[direction] += segment.size()
				
				if total_sizes[opposing_walls[0]] == total_sizes[opposing_walls[1]]:
					var chosen_direction = _rng.randi() % opposing_walls.size()
					main_walls.append(opposing_walls[chosen_direction])
				elif total_sizes[opposing_walls[0]] > total_sizes[opposing_walls[1]]:
					main_walls.append(opposing_walls[0])
				else:
					main_walls.append(opposing_walls[1])
			
			cells[doorway1_direction].clear()
			cells[doorway2_direction].clear()
		elif doorway_walls.size() == 3:
			for direction in cells:
				if doorway_walls.has(direction):
					cells[direction].clear()
				else:
					main_walls.append(direction)
	
	
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



###################################################################################################
# Editor Methods ##################################################################################
###################################################################################################

### Custom Inspector built in functions -----------------------------------------------------------

const ROTATION_GROUP_HINT = "rotation_"

func _get_property_list() -> Array:
	var properties: = []
	
	properties.append({
			name = "_force_lid",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_STORAGE,
	})
	
	var enum_keys := PoolStringArray(["DISABLED"])
	enum_keys.append_array(Sarcophagus.PossibleLids.keys())
	var enum_hint := enum_keys.join(",")
	properties.append({
			name = "force_lid",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_EDITOR,
			hint = PROPERTY_HINT_ENUM,
			hint_string = enum_hint
	})
	
	return properties


func _set(property: String, value) -> bool:
	var has_handled := true
	
	if property == "force_lid":
		if value in Sarcophagus.PossibleLids.keys():
			value = Sarcophagus.PossibleLids[value]
		else:
			value = -1
		_force_lid = value
	else:
		has_handled = false
	
	return has_handled


func _get(property: String):
	var value = null
	
	if property == "force_lid":
		value = "DISABLED" if _force_lid == -1 else Sarcophagus.PossibleLids.keys()[_force_lid]
	
	return value

### -----------------------------------------------------------------------------------------------
