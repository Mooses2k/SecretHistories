# Write your doc string for this file here
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const Fountain = preload("res://scenes/objects/large_objects/fountains_and_wells/medieval_fountain.tscn")
const RoomWalls = preload("res://scenes/worlds/world_gen/helper_objects/crypt_room_walls.gd")

#--- public variables - order: export > normal var > onready --------------------------------------
export var room_purpose_data : Resource = null

export(String, FILE, "*.tscn") var fountain_scene_path := \
	"res://scenes/objects/large_objects/fountains_and_wells/medieval_fountain.tscn"

export(float, 0.0, 360.0, 90.0) var vertical_center_rotation := 90

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
	min_tile_size = Vector2(2, 2) # Vector2(room_purpose_data.requirements[0].min_x_tiles, room_purpose_data.requirements[0].min_y_tiles)
	
	var statue_fountain_rooms := data.get_rooms_of_type(RoomData.OriginalPurpose.FOUNTAIN)
	print("<<<<<<room available = " + str(statue_fountain_rooms))
	if statue_fountain_rooms.empty():
		return
	
	_rng.seed = generation_seed
	for c_value in statue_fountain_rooms:
		var statue_fountain := c_value as RoomData
		var walls_data := RoomWalls.new()
		walls_data.init_from_room(data, statue_fountain, min_tile_size, _rng)
		
		_spawn_middle(data, statue_fountain, walls_data)


func _spawn_middle(world_data: WorldData, statue_fountain: RoomData, walls_data: RoomWalls) -> void:
	var remaining_rect := _get_remaining_rect(statue_fountain, walls_data)
	
	print("<<<<<<check if fountain fits the room>>>>>>>>>")
	if remaining_rect.size < min_tile_size:
		return
	print("<<<<<<SUCCESS fountain fits the room>>>>>>>>>")

	var statue_fountain_rect := Rect2(Vector2.ZERO, min_tile_size)
	statue_fountain_rect.position = remaining_rect.position
	statue_fountain_rect.position += remaining_rect.size / 2.0 - statue_fountain_rect.size / 2.0
	
	var statue_fountain_offset := Vector3(
		statue_fountain_rect.size.x / 2.0 * world_data.CELL_SIZE,
		0,
		statue_fountain_rect.size.y / 2.0 * world_data.CELL_SIZE
	)
	if step_decimals(statue_fountain_rect.position.x) != 0:
		statue_fountain_offset.x += world_data.CELL_SIZE / 2.0
		statue_fountain_rect.position.x = floor(statue_fountain_rect.position.x)
		statue_fountain_rect.size.x += 1
	
	if step_decimals(statue_fountain_rect.position.y) != 0:
		statue_fountain_offset.z += world_data.CELL_SIZE / 2.0
		statue_fountain_rect.position.y = floor(statue_fountain_rect.position.y)
		statue_fountain_rect.size.y += 1
	
	var statue_fountain_cells := _get_center_statue_fountain_cells(world_data, statue_fountain_rect)
	print("<<<<<<<is the statue_fountain_cells empty == " + str(statue_fountain_cells.empty()))
	if not statue_fountain_cells.empty():
		var statue_fountain_rotation := 0.0
		print("<<<<<<<is the statue_fountain_cells empty == " + str(walls_data.main_walls.empty()))
		if not walls_data.main_walls.empty():
			if (
					walls_data.main_walls[0] == WorldData.Direction.EAST 
					or walls_data.main_walls[0] == WorldData.Direction.WEST 
			):
				statue_fountain_rotation = deg2rad(vertical_center_rotation)
		
		_set_statue_fountain_spawn_data(world_data, statue_fountain_cells, -1, statue_fountain_offset, statue_fountain_rotation)


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
					value.position.y += min_tile_size.y
					value.size.y -= min_tile_size.y
			WorldData.Direction.WEST:
				if segments.empty():
					value.position.x += 1
					value.size.x -= 1
				else:
					value.position.x += min_tile_size.x
					value.size.x -= min_tile_size.x
			WorldData.Direction.SOUTH:
				if segments.empty():
					value.size.y -= 1
				else:
					value.size.y -= min_tile_size.y
			WorldData.Direction.EAST:
				if segments.empty():
					value.size.x -= 1
				else:
					value.size.x -= min_tile_size.x
	
	return value


func _get_center_statue_fountain_cells(world_data: WorldData, sarco_rect: Rect2) -> Array:
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
