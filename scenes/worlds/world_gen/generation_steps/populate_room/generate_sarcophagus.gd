# Write your doc string for this file here
tool
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const Sarcophagus = preload("res://scenes/objects/large_objects/sarcophagi/sarcophagus.gd")
const RoomWalls = preload("res://scenes/worlds/world_gen/helper_objects/crypt_room_walls.gd")

#--- public variables - order: export > normal var > onready --------------------------------------

export(String, FILE, "*.tscn") var sarco_scene_path := \
	"res://scenes/objects/large_objects/sarcophagi/sarcophagus.tscn"

export var sarco_tile_size := Vector2(2,2)
export(float, 0.0, 360.0, 90.0) var vertical_center_rotation := 90

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
				var slice = segment.slice(index, index + sarco_tile_size.x - 1)
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
	if not sarco_cells.empty():
		var sarco_rotation := 0.0
		if not walls_data.main_walls.empty():
			if (
					walls_data.main_walls[0] == WorldData.Direction.EAST 
					or walls_data.main_walls[0] == WorldData.Direction.WEST 
			):
				sarco_rotation = deg2rad(vertical_center_rotation)
		
		_set_sarco_spawn_data(world_data, sarco_cells, -1, sarco_offset, sarco_rotation)


func _get_remaining_rect(crypt: RoomData, walls_data: RoomWalls) -> Rect2:
	var value := crypt.rect2
	for direction in walls_data.cells:
		var segments := walls_data.cells[direction] as Array
		
		match direction:
			WorldData.Direction.NORTH:
				if segments.empty():
					value.position.y += 1
					value.size.y -= 1
				else:
					value.position.y += sarco_tile_size.y
					value.size.y -= sarco_tile_size.y
			WorldData.Direction.WEST:
				if segments.empty():
					value.position.x += 1
					value.size.x -= 1
				else:
					value.position.x += sarco_tile_size.x
					value.size.x -= sarco_tile_size.x
			WorldData.Direction.SOUTH:
				if segments.empty():
					value.size.y -= 1
				else:
					value.size.y -= sarco_tile_size.y
			WorldData.Direction.EAST:
				if segments.empty():
					value.size.x -= 1
				else:
					value.size.x -= sarco_tile_size.x
	
	return value


func _get_center_sarco_cells(world_data: WorldData, sarco_rect: Rect2) -> Array:
	var value := []
	
	for offset_x in sarco_rect.size.x:
		var x := (sarco_rect.position.x + offset_x) as float
		for offset_y in sarco_rect.size.y:
			var y := (sarco_rect.position.y + offset_y) as float
			var cell_index := world_data.get_cell_index_from_int_position(x, y)
			value.append(cell_index)
			if not world_data.is_cell_free(cell_index):
				value.clear()
				return value
	
	return value


func _set_sarco_spawn_data(
		data: WorldData, 
		sarco_cells: Array, 
		wall_direction: float, 
		sarco_offset := Vector3.ZERO,
		sarco_rotation := 0.0
) -> void:
	var spawn_data := SpawnData.new()
	spawn_data.scene_path = sarco_scene_path
	
	var spawn_position = (
			data.get_local_cell_position(sarco_cells[0])
			+ sarco_offset
	)
	spawn_data.set_position_in_cell(spawn_position)
	if wall_direction == -1:
		spawn_data.set_y_rotation(sarco_rotation)
	
	var lid_type := Sarcophagus.get_random_lid_type(_rng)
	if _force_lid != -1:
		lid_type = _force_lid
	spawn_data.set_custom_property("current_lid", lid_type)
	spawn_data.set_custom_property("wall_direction", wall_direction)
	spawn_data.set_custom_property("spawnable_items", data.get_sarco_item_list())
	spawn_data.set_custom_property("spawnable_items_amount", data.get_sarco_item_amount_list())
	spawn_data.set_custom_property("sarco_spawnable_items", data.get_sarco_lid_item_list())
	spawn_data.set_custom_property("sarco_spawnable_items_amount", data.get_sarco_lid_item_amount_list())
	
	for cell_index in sarco_cells:
		data.set_object_spawn_data_to_cell(cell_index, spawn_data)
		# if shard_has_spawned == false 


### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

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
