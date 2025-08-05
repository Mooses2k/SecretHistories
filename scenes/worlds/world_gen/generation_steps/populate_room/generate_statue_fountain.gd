# Write your doc string for this file here
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const Fountain = preload("res://scenes/objects/large_objects/fountains_and_wells/medieval_fountain.tscn")
const RoomWalls = preload("res://scenes/worlds/world_gen/helper_objects/crypt_room_walls.gd")

#--- public variables - order: export > normal var > onready --------------------------------------
@export var room_purpose_data : Resource = null

@export_file("*.tscn") var fountain_scene_path := "res://scenes/objects/large_objects/fountains_and_wells/medieval_fountain.tscn"

@export var fountain_tile_size := Vector2(2,2)
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
	print("DEBUG: Found ", statue_fountain_rooms.size(), " fountain rooms")

	if statue_fountain_rooms.is_empty():
		print("DEBUG: No fountain rooms found, skipping fountain generation")
		return

	_rng.seed = generation_seed
	for c_value in statue_fountain_rooms:
		var statue_fountain := c_value as RoomData
		print("DEBUG: Processing fountain room at: ", statue_fountain.rect2)

		var walls_data := RoomWalls.new()
		walls_data.init_from_room(data, statue_fountain, fountain_tile_size, _rng)

		_spawn_middle(data, statue_fountain, walls_data)


func _spawn_middle(world_data: WorldData, statue_fountain: RoomData, walls_data: RoomWalls) -> void:
	var remaining_rect := GenerateInteriorDesign.get_remaining_rect(statue_fountain, walls_data, fountain_tile_size)

	print("DEBUG: Room rect: ", statue_fountain.rect2)
	print("DEBUG: Remaining rect after walls: ", remaining_rect)
	print("DEBUG: Expected room center: ", Vector2(statue_fountain.rect2.position) + Vector2(statue_fountain.rect2.size) / 2.0)

	if not GenerateInteriorDesign.can_place_object(remaining_rect, fountain_tile_size):
		return

	var placement_data := GenerateInteriorDesign.calculate_center_position(
		remaining_rect,
		fountain_tile_size,
		world_data.CELL_SIZE
	)

	print("DEBUG: Placement data rect: ", placement_data.rect)
	print("DEBUG: Placement data offset: ", placement_data.offset)

	var fountain_cells := GenerateInteriorDesign.get_center_cells(world_data, placement_data.rect)

	if not fountain_cells.is_empty():
		var fountain_rotation := GenerateInteriorDesign.calculate_rotation(walls_data, vertical_center_rotation)
		_set_fountain_spawn_data(world_data, fountain_cells, -1, placement_data.offset, fountain_rotation)


func _set_fountain_spawn_data(
		data: WorldData,
		fountain_cells: Array,
		wall_direction: float,
		fountain_offset := Vector3.ZERO,
		fountain_rotation := 0.0
) -> void:
	print("DEBUG: Creating fountain spawn data")
	print("DEBUG: Fountain scene path: ", fountain_scene_path)
	print("DEBUG: Fountain cells: ", fountain_cells)
	print("DEBUG: Fountain offset: ", fountain_offset)
	print("DEBUG: Fountain rotation: ", fountain_rotation)

	# Debug the cell position calculation
	var first_cell_index = fountain_cells[0]
	var cell_world_pos = data.get_local_cell_position(first_cell_index)
	print("DEBUG: First cell index: ", first_cell_index)
	print("DEBUG: Cell world position: ", cell_world_pos)
	print("DEBUG: Final spawn position: ", cell_world_pos + fountain_offset)

	var spawn_data := GenerateInteriorDesign.create_spawn_data(
		data,
		fountain_scene_path,
		fountain_cells[0],
		fountain_offset,
		fountain_rotation if wall_direction == -1 else 0.0
	)

	print("DEBUG: Spawn data created: ", spawn_data)
	print("DEBUG: Spawn data scene path: ", spawn_data.scene_path)
	print("DEBUG: Spawn data amount: ", spawn_data.amount)

	# Debug the actual transform stored in spawn data
	if spawn_data._transforms.size() > 0:
		print("DEBUG: Spawn data transform origin: ", spawn_data._transforms[0].origin)

	for cell_index in fountain_cells:
		print("DEBUG: Setting fountain spawn data to cell: ", cell_index)
		data.set_object_spawn_data_to_cell(cell_index, spawn_data)

### -----------------------------------------------------------------------------------------------

### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

###################################################################################################
# Editor Methods ##################################################################################
###################################################################################################

### Custom Inspector built in functions -----------------------------------------------------------

const ROTATION_GROUP_HINT = "rotation_"

### -----------------------------------------------------------------------------------------------
