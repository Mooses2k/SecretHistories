@tool
# Write your doc string for this file here
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const Sarcophagus = preload("res://scenes/objects/large_objects/sarcophagi/sarcophagus.gd")
const RoomWalls = preload("res://scenes/worlds/world_gen/helper_objects/crypt_room_walls.gd")

#--- public variables - order: export > normal var > onready --------------------------------------

@export_file("*.tscn") var sarco_scene_path := "res://scenes/objects/large_objects/sarcophagi/sarcophagus.tscn"

@export var sarco_tile_size := Vector2(2,2)
@export var vertical_center_rotation := 90 # (float, 0.0, 360.0, 90.0)

@export var _sarco_spawn_list_resource: Resource = null
@export var _sarco_shard_spawn_list_resource: Resource = null
@export var _sarco_lids_spawn_list_resource: Resource = null
@export var _min_item := 0
@export var _max_item := 5

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
	if crypt_rooms.is_empty():
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
	DecorateRooms.process_wall_segments(
		data,
		walls_data,
		direction,
		sarco_tile_size,
		func(cells: Array, wall_direction: int, offset: Vector3 = Vector3.ZERO):
			_set_sarco_spawn_data(data, cells, wall_direction, offset)
	)


func _spawn_middle_sarco(world_data: WorldData, crypt: RoomData, walls_data: RoomWalls) -> void:
	var remaining_rect := DecorateRooms.get_remaining_rect(crypt, walls_data, sarco_tile_size)
	if not DecorateRooms.can_place_object(remaining_rect, sarco_tile_size):
		return

	var placement_data := DecorateRooms.calculate_center_position(
		remaining_rect,
		sarco_tile_size,
		world_data.CELL_SIZE
	)

	var sarco_cells := DecorateRooms.get_center_cells(world_data, placement_data.rect)
	if not sarco_cells.is_empty():
		var sarco_rotation := DecorateRooms.calculate_rotation(walls_data, vertical_center_rotation)
		_set_sarco_spawn_data(world_data, sarco_cells, -1, placement_data.offset, sarco_rotation)


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
	spawn_data.set_custom_property("spawnable_items", _get_sarcophagus_spawn_list())
	spawn_data.set_custom_property("sarco_spawnable_items", _get_lid_spawn_list())

	for cell_index in sarco_cells:
		data.set_object_spawn_data_to_cell(cell_index, spawn_data)


func _get_sarcophagus_spawn_list() -> PackedStringArray:
	var draw_amount := _rng.randi_range(_min_item, _max_item)
	var result : PackedStringArray

	if GameManager.game.current_floor_level == -5 and draw_amount > 0:
		result.push_back((_sarco_shard_spawn_list_resource.get_random_spawn_data(_rng)).scene_path)
		draw_amount -= 1
	for _i in draw_amount:
		result.push_back((_sarco_spawn_list_resource.get_random_spawn_data(_rng)).scene_path)
	return result


func _get_lid_spawn_list() -> PackedStringArray:
	var draw_amount := _rng.randi_range(_min_item, _max_item)
	var result : PackedStringArray
	for _i in draw_amount:
		result.push_back((_sarco_lids_spawn_list_resource.get_random_spawn_data(_rng)).scene_path)
	return result

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
