@tool
# Sarcophagus generation using the new Cell Filtering System
# Refactored to use WallSegmentCellFilter and CenterCellFilter exclusively
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const Sarcophagus = preload("res://scenes/objects/large_objects/sarcophagi/sarcophagus.gd")

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
		
		# Check if room is 4x4 CELL_SIZE and apply 50% chance for center-only generation
		var is_4x4_room := (crypt.rect2.size.x == 4 and crypt.rect2.size.y == 4)
		var use_center_only := is_4x4_room and _rng.randf() < 0.5
		
		if use_center_only:
			# Use center-only generation for 4x4 rooms with 50% chance
			_spawn_center_only_sarcos(data, crypt)
		else:
			# Use original wall-based generation
			# Create wall segment filter configured for sarcophagi
			var wall_filter := WallSegmentCellFilter.new()
			wall_filter.set_object_size(sarco_tile_size)
			
			# Get wall placement data using the filter (preserves exact working flow)
			var placement_data := wall_filter.get_wall_segments_for_placement(data, crypt, _rng)
			
			# Process main walls first (exact flow from original: lines 56-57)
			for segment_data in placement_data.main_wall_segments:
				_spawn_sarcos_in_wall_segment(data, wall_filter, segment_data)
			
			# Process other walls (exact flow from original: lines 59-62)
			for segment_data in placement_data.other_wall_segments:
				_spawn_sarcos_in_wall_segment(data, wall_filter, segment_data)
			
			# Spawn center sarcophagus using proper space validation (exact flow from original: line 64)
			_spawn_middle_sarco(data, crypt, wall_filter)


func _spawn_sarcos_in_wall_segment(
		data: WorldData, wall_filter: WallSegmentCellFilter, segment_data: Dictionary
) -> void:
	wall_filter.process_wall_segments(
		data,
		segment_data.direction,
		func(cells: Array, wall_direction: int, offset: Vector3 = Vector3.ZERO):
			_set_sarco_spawn_data(data, cells, wall_direction, offset)
	)


func _spawn_center_only_sarcos(world_data: WorldData, crypt: RoomData) -> void:
	# Create center filter for independent center-only placement
	var center_filter := CenterCellFilter.new()
	center_filter.set_object_size(sarco_tile_size)
	
	# Get center placement data without wall constraints
	var placement_data := center_filter.get_center_placement_data(world_data, crypt)
	
	if not placement_data.is_empty():
		# Use default rotation for center-only placement
		var sarco_rotation := deg_to_rad(vertical_center_rotation)
		_set_sarco_spawn_data(world_data, placement_data.cells, -1, placement_data.offset, sarco_rotation)


func _spawn_middle_sarco(world_data: WorldData, crypt: RoomData, wall_filter: WallSegmentCellFilter) -> void:
	# Create center filter with wall data for proper space calculation
	var center_filter := CenterCellFilter.new()
	center_filter.set_object_size(sarco_tile_size)
	center_filter.set_walls_data(wall_filter)
	
	# Get center placement data
	var placement_data := center_filter.get_center_placement_data(world_data, crypt)
	
	if not placement_data.is_empty():
		# Calculate rotation
		var sarco_rotation := wall_filter.calculate_rotation(vertical_center_rotation)
		_set_sarco_spawn_data(world_data, placement_data.cells, -1, placement_data.offset, sarco_rotation)


func _set_sarco_spawn_data(
		data: WorldData,
		sarco_cells: Array,
		wall_direction: float,
		sarco_offset := Vector3.ZERO,
		sarco_rotation := 0.0
) -> void:
	var spawn_data := SarcophagusSpawnData.new()
	spawn_data.scene_path = sarco_scene_path
	spawn_data.amount = 1

	# Use CellFilter utility instead of direct WorldData call
	var spawn_position = (
			CellFilter.get_cell_position(data, sarco_cells[0])
			+ sarco_offset
	)
	spawn_data.set_position_in_cell(spawn_position)
	if wall_direction == -1:
		spawn_data.set_y_rotation(sarco_rotation)

	var lid_type := Sarcophagus.get_random_lid_type(_rng)
	if _force_lid != -1:
		lid_type = _force_lid
	
	# Configure sarcophagus-specific properties
	spawn_data.configure_sarcophagus(lid_type, wall_direction, _get_sarcophagus_spawn_list())
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
