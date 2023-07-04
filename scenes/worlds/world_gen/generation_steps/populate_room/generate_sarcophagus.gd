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

export var sarco_tile_length := 3
export var min_size_for_middle_sarco := 6
# Angle in degrees that the sarcos have to be rotated when spawning in each direction
export(float, -360.0, 360.0, 1.0) var rotation_north := 0.0
export(float, -360.0, 360.0, 1.0) var rotation_east := 90.0
export(float, -360.0, 360.0, 1.0) var rotation_south := 180.0
export(float, -360.0, 360.0, 1.0) var rotation_west := 270.0

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
		var walls_data := _get_walls_data(data, crypt)
		print("Crypt Walls: %s"%[walls_data])
		_spawn_sarcos_on_walls(data, walls_data)
		
		if crypt.is_min_dimension_greater_or_equal_to(min_size_for_middle_sarco):
			_spawn_middle_sarco(data, crypt)


func _get_walls_data(data: WorldData, crypt: RoomData) -> RoomWalls:
	var walls_data := RoomWalls.new()
	
	for cell_index in crypt.cell_indexes:
		for direction in WorldData.Direction.values():
			if direction == WorldData.Direction.DIRECTION_MAX:
				continue
			
			var edge_type := data.get_wall_type(cell_index, direction)
			match edge_type:
				WorldData.EdgeType.WALL:
					walls_data.cells[direction].append(cell_index)
	
	return walls_data


func _spawn_sarcos_on_walls(data: WorldData, walls_data: RoomWalls) -> void:
	for direction in WorldData.Direction.values():
		if direction == WorldData.Direction.DIRECTION_MAX:
			continue
		
		var valid_cells_in_wall := walls_data.get_grouped_cells_on_wall(
				data, direction, sarco_tile_length
		)
		print("valid_cells_in_wall: %s"%[valid_cells_in_wall])
		var sarco_rotation = _get_sarco_rotation(direction)
		for grouped_cells in valid_cells_in_wall:
			var spawn_data := SpawnData.new()
			spawn_data.scene_path = sarco_scene_path
			var spawn_position = data.get_local_cell_position(grouped_cells[0])
			spawn_data.set_y_rotation(sarco_rotation)
			spawn_data.set_position_in_cell(spawn_position)
			var lid_type := Sarcophagus.get_random_lid_type(_rng)
			spawn_data.set_custom_property("current_lid", lid_type)
			
			for cell_index in grouped_cells:
				data.set_object_spawn_data_to_cell(cell_index, spawn_data)


func _spawn_middle_sarco(data: WorldData, crypt: RoomData) -> void:
	pass


func _get_sarco_rotation(direction: int) -> float:
	var value := rotation_north
	
	match direction:
		WorldData.Direction.EAST:
			value = rotation_east
		WorldData.Direction.SOUTH:
			value = rotation_south
		WorldData.Direction.WEST:
			value = rotation_west
	
	return value

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

class RoomWalls extends Reference:
	# This holds all the indexes from the room walls, excluding doors.
	var cells := {
			WorldData.Direction.NORTH: [],
			WorldData.Direction.EAST: [],
			WorldData.Direction.SOUTH: [],
			WorldData.Direction.WEST: [],
	}
	
	func _to_string() -> String:
		var msg := "RoomWalls:"
		
		for direction in cells:
			msg += "\n %s: %s"%[WorldData.Direction.keys()[direction], cells[direction]]
		
		return msg
	
	
	# Returns an array of coupled wall indexes indexes, they have to be neighbours on the same
	# wall, that is, not interrupted by any doors. They also need to have as many indexes as the
	# length of the sarco
	# ex: [ [101, 131, 161], [141, 142, 143],...
	func get_grouped_cells_on_wall(data: WorldData, direction: int, sarco_tile_length: int) -> Array:
		var grouped_cells := []
		var wall_indexes := cells[direction] as Array
		if wall_indexes.size() < sarco_tile_length:
			return grouped_cells
		
		var length_direction := data.direction_rotate_cw(direction)
		if direction == WorldData.Direction.SOUTH or direction == WorldData.Direction.WEST:
			length_direction = data.direction_rotate_ccw(direction)
		
		for index in range(0, wall_indexes.size(), sarco_tile_length):
			var cell_indexes := []
			var next_index := index
			for _i in sarco_tile_length:
				cell_indexes.append(wall_indexes[next_index])
				next_index += 1
				if next_index >= wall_indexes.size():
					break
			
			print("index: %s | cell_indexes: %s "%[index, cell_indexes])
			if cell_indexes.size() < sarco_tile_length:
				continue
			
			var are_cell_adjacent := true
			for c_index in range(0, cell_indexes.size()-1):
				var current_cell := cell_indexes[c_index] as int
				var next_cell := cell_indexes[c_index + 1] as int
				if (
						next_cell != data.get_neighbour_cell(current_cell, length_direction)
						or not data.is_cell_free(current_cell)
						or not data.is_cell_free(next_cell)
				):
					are_cell_adjacent = false
			
			if are_cell_adjacent:
				grouped_cells.append(cell_indexes)
		
		return grouped_cells
