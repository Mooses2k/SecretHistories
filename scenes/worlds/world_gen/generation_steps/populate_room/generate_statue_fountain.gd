# Write your doc string for this file here
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const Fountain = preload("res://scenes/objects/large_objects/fountains_and_wells/medieval_fountain.tscn")
const RoomWalls = preload("res://scenes/worlds/world_gen/helper_objects/crypt_room_walls.gd")
const RoomPlacementUtils = preload("res://scenes/worlds/world_gen/generation_steps/room_placement_utils.gd")

#--- public variables - order: export > normal var > onready --------------------------------------
@export var room_purpose_data : Resource = null

@export_file("*.tscn") var fountain_scene_path := \
	"res://scenes/objects/large_objects/fountains_and_wells/medieval_fountain.tscn"

@export_range(0.0, 360.0, 90.0) var vertical_center_rotation := 90

#--- private variables - order: export > normal var > onready -------------------------------------

var _rng := RandomNumberGenerator.new()
var min_tile_size : Vector2

### -----------------------------------------------------------------------------------------------

### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

### Private Methods -------------------------------------------------------------------------------

func _execute_step(data : WorldData, _gen_data : Dictionary, generation_seed : int):
	min_tile_size = Vector2(room_purpose_data.requirements[0].min_x_tiles, room_purpose_data.requirements[0].min_y_tiles)
	
	var statue_fountain_rooms := data.get_rooms_of_type(RoomData.OriginalPurpose.FOUNTAIN)
	print("<<<<<<room available = " + str(statue_fountain_rooms))
	if statue_fountain_rooms.is_empty():
		return
	
	_rng.seed = generation_seed
	for c_value in statue_fountain_rooms:
		var statue_fountain := c_value as RoomData
		var walls_data := RoomWalls.new()
		walls_data.init_from_room(data, statue_fountain, min_tile_size, _rng)
		
		_spawn_middle(data, statue_fountain, walls_data)


func _spawn_middle(world_data: WorldData, statue_fountain: RoomData, walls_data: RoomWalls) -> void:
	var remaining_rect := RoomPlacementUtils.get_remaining_rect(statue_fountain, walls_data, min_tile_size)
	
	print("<<<<<<check if fountain fits the room>>>>>>>>>")
	if not RoomPlacementUtils.can_place_object(remaining_rect, min_tile_size):
		return
	print("<<<<<<SUCCESS fountain fits the room>>>>>>>>>")

	var placement_data := RoomPlacementUtils.calculate_center_position(
		remaining_rect, 
		min_tile_size, 
		world_data.CELL_SIZE
	)
	
	var statue_fountain_cells := RoomPlacementUtils.get_center_cells(world_data, placement_data.rect)
	print("<<<<<<<is the statue_fountain_cells empty == " + str(statue_fountain_cells.is_empty()))
	if not statue_fountain_cells.is_empty():
		var statue_fountain_rotation := RoomPlacementUtils.calculate_rotation(walls_data, vertical_center_rotation)
		print("<<<<<<<is the statue_fountain_cells empty == " + str(walls_data.main_walls.is_empty()))
		if not walls_data.main_walls.is_empty():
			if (
					walls_data.main_walls[0] == WorldData.Direction.EAST 
					or walls_data.main_walls[0] == WorldData.Direction.WEST 
			):
				statue_fountain_rotation = deg_to_rad(vertical_center_rotation)
		
		_set_statue_fountain_spawn_data(world_data, statue_fountain_cells, -1, placement_data.offset, statue_fountain_rotation)


func _set_statue_fountain_spawn_data(
		data: WorldData, 
		sarco_cells: Array, 
		wall_direction: float, 
		sarco_offset := Vector3.ZERO,
		sarco_rotation := 0.0
) -> void:
	var spawn_data := SpawnData.new()
	spawn_data.scene_path = fountain_scene_path
	
	var spawn_position = (
			data.get_local_cell_position(sarco_cells[0])
			+ sarco_offset
	)
	spawn_data.set_position_in_cell(spawn_position)
	if wall_direction == -1:
		spawn_data.set_y_rotation(sarco_rotation)
	
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

### -----------------------------------------------------------------------------------------------
