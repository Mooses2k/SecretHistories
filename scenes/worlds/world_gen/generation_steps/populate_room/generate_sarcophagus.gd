@tool
# Write your doc string for this file here
extends GenerationStep

#- Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const RoomWalls = preload("res://scenes/worlds/world_gen/helper_objects/crypt_room_walls.gd")

#--- public variables - order: export > normal var > onready --------------------------------------

@export_file("*.tscn") var sarco_scene_path := "res://scenes/objects/large_objects/sarcophagi/sarcophagus.tscn"

@export var sarco_tile_size := Vector2(2,2)
@export_range(0.0,360.0,90.0) var vertical_center_rotation := 90

@export_group("Spawns Inside Sarcophagus", "_inside_")
@export var _inside_min_spawns := 0
@export var _inside_max_spawns := 5
@export var _inside_spawn_list: ObjectSpawnList = null

@export_group("Spawns on Lid", "_lid_")
@export var _lid_min_spawns := 0
@export var _lid_max_spawns := 5
@export var _lid_spawn_list: ObjectSpawnList = null

#--- private variables - order: export > normal var > onready -------------------------------------

var _generated_sarco_spawn_data: Array[SarcophagusSpawnData] = []

var _force_lid := -1
var _rng := RandomNumberGenerator.new()
var _astar: ManhattanAStar2D = null

#--------------------------------------------------------------------------------------------------


#- Built-in Virtual Overrides --------------------------------------------------------------------

#--------------------------------------------------------------------------------------------------


#- Public Methods --------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------------------


#- Private Methods -------------------------------------------------------------------------------

func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	_rng.seed = generation_seed
	_astar = gen_data[KEY_ASTAR]
	_generate_all_sarco_spawn_data(data)
	_generate_sarco_items()


func _generate_all_sarco_spawn_data(data:WorldData) -> void:
	var crypt_rooms := data.get_rooms_of_type(RoomData.OriginalPurpose.CRYPT)
	if crypt_rooms.is_empty():
		return
	
	for c_value in crypt_rooms:
		var crypt := c_value as RoomData
		var walls_data := RoomWalls.new()
		walls_data.init_from_room(data, crypt, sarco_tile_size, _rng)
		
		for direction in walls_data.main_walls:
			_spawn_sarcos_in_wall_segments(data, walls_data, direction)
		
		for direction in walls_data.cells:
			if direction in walls_data.main_walls:
				continue
			_spawn_sarcos_in_wall_segments(data, walls_data, direction)
		
		_spawn_middle_sarco(data, crypt, walls_data)


func _spawn_sarcos_in_wall_segments(
		data: WorldData, walls_data: RoomWalls, direction: int
) -> void:
	var segments := walls_data.get_sanitized_segments_for(data, direction, sarco_tile_size)
	for value in segments:
		var segment := value as Array
		var surplus_cells := segment.size() % int(sarco_tile_size.x)
		if surplus_cells == 0:
			for index in range(0, segment.size(), sarco_tile_size.x):
				var slice = segment.slice(index, index + int(sarco_tile_size.x))
				var sarco_cells := _get_all_cells_for_sarco_segment(data, slice, direction)
				_set_sarco_spawn_data(data, sarco_cells, direction)
		else:
			var sarco_cells := _get_all_cells_for_sarco_segment(data, segment, direction)
			var sarco_offset := _get_sarco_offset(direction, surplus_cells) * data.CELL_SIZE
			_set_sarco_spawn_data(data, sarco_cells, direction, sarco_offset)


func _get_all_cells_for_sarco_segment(data: WorldData, segment: Array, direction: int) -> Array:
	var width_direction := data.direction_inverse(direction)
	var sarco_cells := []
	
	for cell_index in segment:
		# Remove sarco cells close to walls from Astar
		if _astar.has_point(cell_index):
			_astar.remove_point(cell_index)
		
		sarco_cells.append(cell_index)
		for _width in sarco_tile_size.y - 1:
			cell_index = data.get_neighbour_cell(cell_index, width_direction)
			sarco_cells.append(cell_index)
	
	return sarco_cells


func _get_sarco_offset(direction: int, surplus_cells := 0) -> Vector3:
	var value := Vector3.ZERO
	
	var center_offset := surplus_cells / 2.0
	match direction:
		WorldData.Direction.NORTH, WorldData.Direction.SOUTH:
			value = Vector3(center_offset, 0, 0)
		WorldData.Direction.EAST, WorldData.Direction.WEST:
			value = Vector3(0, 0, center_offset)
	
	return value


func _spawn_middle_sarco(world_data: WorldData, crypt: RoomData, walls_data: RoomWalls) -> void:
	var remaining_rect := _get_remaining_rect(crypt, walls_data)
	if remaining_rect.size < sarco_tile_size:
		return
	
	var sarco_rect := Rect2(Vector2.ZERO, sarco_tile_size)
	sarco_rect.position = remaining_rect.position
	sarco_rect.position += remaining_rect.size / 2.0 - sarco_rect.size / 2.0
	
	var sarco_offset := Vector3(
		sarco_rect.size.x / 2.0 * world_data.CELL_SIZE,
		0,
		sarco_rect.size.y / 2.0 * world_data.CELL_SIZE
	)
	if step_decimals(sarco_rect.position.x) != 0:
		sarco_offset.x += world_data.CELL_SIZE / 2.0
		sarco_rect.position.x = floor(sarco_rect.position.x)
		sarco_rect.size.x += 1
	
	if step_decimals(sarco_rect.position.y) != 0:
		sarco_offset.z += world_data.CELL_SIZE / 2.0
		sarco_rect.position.y = floor(sarco_rect.position.y)
		sarco_rect.size.y += 1
	
	var sarco_cells := _get_center_sarco_cells(world_data, sarco_rect)
	if not sarco_cells.is_empty():
		var sarco_rotation := 0.0
		if not walls_data.main_walls.is_empty():
			if (
					walls_data.main_walls[0] == WorldData.Direction.EAST 
					or walls_data.main_walls[0] == WorldData.Direction.WEST 
			):
				sarco_rotation = deg_to_rad(vertical_center_rotation)
		
		_set_sarco_spawn_data(world_data, sarco_cells, -1, sarco_offset, sarco_rotation)


func _get_remaining_rect(crypt: RoomData, walls_data: RoomWalls) -> Rect2:
	var value := crypt.rect2
	for direction in walls_data.cells:
		var segments := walls_data.cells[direction] as Array
		
		match direction:
			WorldData.Direction.NORTH:
				if segments.is_empty():
					value.position.y += 1
					value.size.y -= 1
				else:
					value.position.y += int(sarco_tile_size.y)
					value.size.y -= int(sarco_tile_size.y)
			WorldData.Direction.WEST:
				if segments.is_empty():
					value.position.x += 1
					value.size.x -= 1
				else:
					value.position.x += int(sarco_tile_size.x)
					value.size.x -= int(sarco_tile_size.x)
			WorldData.Direction.SOUTH:
				if segments.is_empty():
					value.size.y -= 1
				else:
					value.size.y -= int(sarco_tile_size.y)
			WorldData.Direction.EAST:
				if segments.is_empty():
					value.size.x -= 1
				else:
					value.size.x -= int(sarco_tile_size.x)
	
	return value


func _get_center_sarco_cells(world_data: WorldData, sarco_rect: Rect2) -> Array:
	var value := []
	
	for offset_x in sarco_rect.size.x:
		var x := int(sarco_rect.position.x + offset_x)
		for offset_y in sarco_rect.size.y:
			var y := int(sarco_rect.position.y + offset_y)
			var cell_index := world_data.get_cell_index_from_int_position(x, y)
			value.append(cell_index)
			if not world_data.is_cell_free(cell_index):
				value.clear()
				return value
	
	return value


func _set_sarco_spawn_data(
		data: WorldData, 
		sarco_cells: Array, 
		wall_direction: int, 
		sarco_offset := Vector3.ZERO,
		sarco_rotation := 0.0
) -> void:
	var spawn_data := SarcophagusSpawnData.new()
	spawn_data.scene_path = sarco_scene_path
	
	var spawn_position = (
			data.get_local_cell_position(sarco_cells[0])
			+ sarco_offset
	)
	spawn_data.set_position_in_cell(spawn_position)
	if wall_direction == -1:
		spawn_data.set_y_rotation(sarco_rotation)
	
	if _force_lid != -1:
		spawn_data.lid_type = _force_lid as Sarcophagus.PossibleLids
	else:
		spawn_data.set_random_lid_type(_rng)
	
	spawn_data.wall_direction = wall_direction
	
	_generated_sarco_spawn_data.append(spawn_data)
	for cell_index in sarco_cells:
		data.set_object_spawn_data_to_cell(cell_index, spawn_data)


func _generate_sarco_items() -> void:
	if GameManager.game.current_floor_level == Game.LOWEST_FLOOR_LEVEL:
		var shard_sarco_index := _rng.randi() % _generated_sarco_spawn_data.size()
		var shard_sarco := _generated_sarco_spawn_data[shard_sarco_index]
		_add_spawn_itens_to_sarcos(shard_sarco, true)
		_generated_sarco_spawn_data.remove_at(shard_sarco_index)
	
	for _index in range(_generated_sarco_spawn_data.size()-1, -1, -1):
		var sarco := _generated_sarco_spawn_data.pop_back() as SarcophagusSpawnData
		_add_spawn_itens_to_sarcos(sarco, false)


func _add_spawn_itens_to_sarcos(sarco: SarcophagusSpawnData, has_shard: bool) -> void:
	var inside_amount := _rng.randi_range(_inside_min_spawns, _inside_max_spawns)
	if has_shard and inside_amount == 0:
		inside_amount = 1
	sarco.set_inside_spawns(inside_amount, _inside_spawn_list, _rng, has_shard)
	
	var lid_amount = _rng.randi_range(_lid_min_spawns, _lid_max_spawns)
	sarco.set_lid_spawns(lid_amount, _lid_spawn_list, _rng)

#--------------------------------------------------------------------------------------------------


#- Signal Callbacks ------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------------------
# Editor Methods ----------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------------

#- Custom Inspector built in functions -----------------------------------------------------------

const ROTATION_GROUP_HINT = "rotation_"


func _get_property_list() -> Array:
	var properties: = []
	
	properties.append({
			name = "_force_lid",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_STORAGE,
	})
	
	var enum_keys := PackedStringArray(["DISABLED"])
	enum_keys.append_array(Sarcophagus.PossibleLids.keys())
	var enum_hint := ",".join(enum_keys)
	properties.append({
			name = "force_lid",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_EDITOR,
			hint = PROPERTY_HINT_ENUM,
			hint_string = enum_hint
	})
	
	return properties


func _set(property: StringName, value) -> bool:
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


func _get(property: StringName):
	var value = null
	
	if property == "force_lid":
		value = "DISABLED" if _force_lid == -1 else Sarcophagus.PossibleLids.keys()[_force_lid]
	
	return value

#--------------------------------------------------------------------------------------------------
