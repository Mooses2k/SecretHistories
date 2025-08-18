## Generates candelabra in room corners using the cell filtering system
## Consolidates corner placement and door proximity logic into CornerCellFilter
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const UNLIT_KEYWORD = "unlit"
const MAX_X_UNLIT_ROTATION = deg_to_rad(20)   # 30 is enough to rarely glitch it into a wall
const MAX_Z_UNLIT_ROTATION = deg_to_rad(20)

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

# Rooms must have both sides greater or equal to this value to be considered
# for spawning candelabra
@export var _single_tile_size_threshold := 4
@export var _room_chance := .95 if GameManager.game.current_floor_level >= -2 else 0.6 # (float, 0.0,1.0,0.01)
@export var _spawn_list_resource: Resource = null

var _rng := RandomNumberGenerator.new()
var _corner_filter := CornerCellFilter.new()

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _execute_step(data : WorldData, _gen_data : Dictionary, generation_seed : int):
	_rng.seed = generation_seed
	
	# Configure corner filter to avoid doors (consolidates door proximity logic)
	_corner_filter.set_avoid_doors(true)

	var all_rooms := data.get_all_rooms()
	var valid_rooms := _get_valid_rooms(all_rooms)
	for entry in valid_rooms:
		if _rng.randf() <= _room_chance:
			_handle_candelabra(data, entry)


func _get_valid_rooms(p_array: Array) -> Array:
	var valid_rooms := []

	for entry in p_array:
		var room_data := entry as RoomData
		if room_data.is_min_dimension_greater_or_equal_to(_single_tile_size_threshold):
			valid_rooms.append(room_data)

#	print("valid rooms for candelabra: %s"%[valid_rooms])

	return valid_rooms


func _handle_candelabra(world_data: WorldData, room_data: RoomData) -> void:
	var spawn_list := _spawn_list_resource as ObjectSpawnList
	
	# Use CornerCellFilter to get valid corner cells (replaces manual corner iteration and door checks)
	var valid_corner_cells := _corner_filter.filter_cells(world_data, room_data, _rng)
	
	# Get corner data for rotation calculations
	var corners := room_data.get_corners_data()
	
	for corner_cell_index in valid_corner_cells:
		# Get cell position using CellFilter utility
		var cell_position := CellFilter.get_cell_position(world_data, corner_cell_index)
		var spawn_data := spawn_list.get_random_spawn_data(_rng)
		
		if not spawn_data.scene_path.is_empty():
			spawn_data.set_center_position_in_cell(cell_position)
			
			if spawn_data.scene_path.find(UNLIT_KEYWORD) != -1:
				spawn_data.set_random_rotation_in_all_axis(
						_rng,
						MAX_X_UNLIT_ROTATION,
						TAU,
						MAX_Z_UNLIT_ROTATION
				)
			else:
				# Find the corner type for this cell to get proper facing angle
				var corner_key := _find_corner_key_for_cell(world_data, room_data, corner_cell_index)
				if corner_key != -1:
					var facing_angle := corners.get_facing_angle_for(corner_key)
					spawn_data.set_y_rotation(facing_angle)

			world_data.set_object_spawn_data_to_cell(corner_cell_index, spawn_data)
		else:
#			print("No candelabra to spawn in this corner: %s"%[corner_cell_index])
			pass


## Helper method to find which corner key corresponds to a given cell index
## This replaces the need for manual corner iteration
func _find_corner_key_for_cell(world_data: WorldData, room_data: RoomData, cell_index: int) -> int:
	var corners := room_data.get_corners_data()
	var cell_int_pos := CellFilter.get_int_position_from_cell(world_data, cell_index)
	var cell_x: int = cell_int_pos[0]
	var cell_y: int = cell_int_pos[1]
	
	for key in corners.corner_positions:
		var corner := corners.corner_positions[key] as Vector2
		if int(corner.x) == cell_x and int(corner.y) == cell_y:
			return key
	
	return -1  # Corner not found


## Legacy methods removed - functionality now handled by CornerCellFilter:
## - _get_walls_world_data_directions_for() - door checking now in CornerCellFilter
## - _is_corner_next_to_door() - door proximity logic consolidated in CornerCellFilter.filter_cells_away_from_doors()

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
