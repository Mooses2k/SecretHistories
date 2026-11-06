@tool
# Trophy room generation using the Cell Filtering System
# Modeled on generate_sarcophagus.gd: wall segments at 2x2 spacing plus a center pedestal.
# Wall slots roll 50/50 between a statue and a pedestal; the center is always a pedestal.
# Pedestals carry loot via the spawnable_items custom property, consumed by the
# AnchorSpawner embedded in pedestal.tscn (same flow as sarcophagus loot).
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const TROPHY_TILE_SIZE := Vector2(2, 2)

const PEDESTAL_SCENE_PATH := "res://scenes/objects/large_objects/pedestal/pedestal.tscn"

# Grid direction vectors per WorldData.Direction (x, z). NORTH is -z, EAST is +x.
const DIRECTION_GRID_OFFSETS := {
	WorldData.Direction.NORTH: Vector2(0, -1),
	WorldData.Direction.EAST: Vector2(1, 0),
	WorldData.Direction.SOUTH: Vector2(0, 1),
	WorldData.Direction.WEST: Vector2(-1, 0),
}

# Y rotation (radians) that makes an object's forward (-Z) face the given direction.
const FACE_ROTATION := {
	WorldData.Direction.NORTH: 0.0,
	WorldData.Direction.EAST: -PI / 2,
	WorldData.Direction.SOUTH: PI,
	WorldData.Direction.WEST: PI / 2,
}

#--- public variables - order: export > normal var > onready --------------------------------------

@export var statue_spawn_list : Resource = null
@export_file("*.tscn") var pedestal_scene_path := PEDESTAL_SCENE_PATH
@export var item_spawn_list : Resource = null
@export var _min_item := 0
@export var _max_item := 5

#--- private variables - order: export > normal var > onready -------------------------------------

var _rng := RandomNumberGenerator.new()

### -----------------------------------------------------------------------------------------------

### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

### Private Methods -------------------------------------------------------------------------------

func _execute_step(data : WorldData, _gen_data : Dictionary, generation_seed : int):
	var trophy_rooms := data.get_rooms_of_type(RoomData.OriginalPurpose.TROPHY_ROOM)
	if trophy_rooms.is_empty():
		return

	if statue_spawn_list == null:
		push_error("GenerateTrophyRoom: statue_spawn_list is not set")
		return
	if item_spawn_list == null:
		push_error("GenerateTrophyRoom: item_spawn_list is not set")
		return

	_rng.seed = generation_seed
	for c_value in trophy_rooms:
		var trophy_room := c_value as RoomData

		# 4x4 rooms get a 50% chance for center-only generation (sarcophagus pattern)
		var is_4x4_room := (trophy_room.rect2.size.x == 4 and trophy_room.rect2.size.y == 4)
		var use_center_only := is_4x4_room and _rng.randf() < 0.5

		if use_center_only:
			_spawn_center_only(data, trophy_room)
		else:
			var wall_filter := WallSegmentCellFilter.new()
			wall_filter.set_object_size(TROPHY_TILE_SIZE)

			var placement_data := wall_filter.get_wall_segments_for_placement(data, trophy_room, _rng)

			for segment_data in placement_data.main_wall_segments:
				_spawn_objects_in_wall_segment(data, wall_filter, segment_data)
			for segment_data in placement_data.other_wall_segments:
				_spawn_objects_in_wall_segment(data, wall_filter, segment_data)

			_spawn_middle(data, trophy_room, wall_filter)


func _spawn_objects_in_wall_segment(
		data: WorldData, wall_filter: WallSegmentCellFilter, segment_data: Dictionary
) -> void:
	wall_filter.process_wall_segments(
		data,
		segment_data.direction,
		func(cells: Array, wall_direction: int, offset: Vector3 = Vector3.ZERO):
			# 50/50 roll per wall slot: statue or pedestal
			if _rng.randf() < 0.5:
				_set_statue_spawn_data(data, cells, wall_direction, offset)
			else:
				_set_pedestal_spawn_data(data, cells, wall_direction, offset)
	)


func _spawn_center_only(world_data: WorldData, trophy_room: RoomData) -> void:
	var center_filter := CenterCellFilter.new()
	center_filter.set_object_size(TROPHY_TILE_SIZE)

	var placement_data := center_filter.get_center_placement_data(world_data, trophy_room)

	if not placement_data.is_empty():
		_set_pedestal_spawn_data(world_data, placement_data.cells, -1, placement_data.offset, trophy_room)


func _spawn_middle(world_data: WorldData, trophy_room: RoomData, wall_filter: WallSegmentCellFilter) -> void:
	var center_filter := CenterCellFilter.new()
	center_filter.set_object_size(TROPHY_TILE_SIZE)
	center_filter.set_walls_data(wall_filter)

	var placement_data := center_filter.get_center_placement_data(world_data, trophy_room)

	if not placement_data.is_empty():
		_set_pedestal_spawn_data(world_data, placement_data.cells, -1, placement_data.offset, trophy_room)


func _set_statue_spawn_data(
		data: WorldData,
		trophy_cells: Array,
		wall_direction: float,
		slot_offset := Vector3.ZERO
) -> void:
	if trophy_cells.is_empty():
		return

	var statue_spawn: SpawnData = statue_spawn_list.get_random_spawn_data(_rng)
	if statue_spawn.scene_path.is_empty():
		return

	var spawn_data := SpawnData.new()
	spawn_data.scene_path = statue_spawn.scene_path
	spawn_data.amount = 1

	# 1x1 statue centered in the 2x2 slot: one full cell along the wall and one full
	# cell into the room. Cell positions are cell corners, not centers.
	var center_offset := _get_slot_center_offset(data, trophy_cells[0], wall_direction)
	var spawn_position = (
			CellFilter.get_cell_position(data, trophy_cells[0])
			+ center_offset
			+ slot_offset
	)
	spawn_data.set_position_in_cell(spawn_position)

	if wall_direction == -1:
		spawn_data.set_y_rotation(FACE_ROTATION[WorldData.Direction.SOUTH])
	else:
		# Face away from the wall, into the room
		spawn_data.set_y_rotation(FACE_ROTATION[data.direction_inverse(int(wall_direction))])

	for cell_index in trophy_cells:
		data.set_object_spawn_data_to_cell(cell_index, spawn_data)


func _get_pedestal_item_list() -> PackedStringArray:
	var result : PackedStringArray
	var draw_amount := _rng.randi_range(_min_item, _max_item)
	for _i in draw_amount:
		result.push_back((item_spawn_list.get_random_spawn_data(_rng)).scene_path)
	return result


func _set_pedestal_spawn_data(
		data: WorldData,
		trophy_cells: Array,
		wall_direction: float,
		slot_offset := Vector3.ZERO,
		center_room: RoomData = null
) -> void:
	if trophy_cells.is_empty():
		return

	var spawn_data := SpawnData.new()
	spawn_data.scene_path = pedestal_scene_path
	spawn_data.amount = 1

	var center_offset := _get_slot_center_offset(data, trophy_cells[0], wall_direction)
	var spawn_position = (
			CellFilter.get_cell_position(data, trophy_cells[0])
			+ center_offset
			+ slot_offset
	)
	spawn_data.set_position_in_cell(spawn_position)

	if wall_direction == -1:
		spawn_data.set_y_rotation(_get_center_facing_rotation(center_room))
	else:
		# Face away from the wall, into the room
		spawn_data.set_y_rotation(FACE_ROTATION[data.direction_inverse(int(wall_direction))])

	# Loot rides on the pedestal as the spawnable_items custom property; the pedestal's
	# embedded AnchorSpawner places the items on its PlacementAnchor (sarcophagus flow).
	var loot_items := _get_pedestal_item_list()
	spawn_data.set_custom_property("spawnable_items", loot_items)

	for cell_index in trophy_cells:
		data.set_object_spawn_data_to_cell(cell_index, spawn_data)


## Offset from the first cell of a 2x2 slot to the slot center, in world units.
## Length runs along the wall, width runs into the room; both are one full cell
## because get_local_cell_position returns the cell corner, not its center.
## Surplus slots additionally get the filter's half-cell wall_offset along the wall.
## Center placements (wall_direction -1) already carry the full 2x2 offset in slot_offset.
func _get_slot_center_offset(data: WorldData, first_cell_index: int, wall_direction: int) -> Vector3:
	if wall_direction == -1:
		return Vector3.ZERO
	var grid_offset := Vector2.ONE
	var direction := wall_direction as int
	var length_offset: Vector2
	if direction == WorldData.Direction.NORTH or direction == WorldData.Direction.EAST:
		length_offset = DIRECTION_GRID_OFFSETS[data.direction_rotate_cw(direction)]
	else:
		length_offset = DIRECTION_GRID_OFFSETS[data.direction_rotate_ccw(direction)]
	var width_offset: Vector2 = DIRECTION_GRID_OFFSETS[data.direction_inverse(direction)]
	# NORTH/WEST walls sit on the wall cell's min edge (wall face == cell corner);
	# SOUTH/EAST walls sit on the max edge (wall face == corner + 1 cell), so their
	# slot straddles the corner and the center needs the +1 cell correction back.
	if direction == WorldData.Direction.SOUTH or direction == WorldData.Direction.EAST:
		width_offset += DIRECTION_GRID_OFFSETS[direction]
	grid_offset = Vector2(length_offset.x + width_offset.x, length_offset.y + width_offset.y)

	return Vector3(grid_offset.x, 0, grid_offset.y) * data.CELL_SIZE


## Center pedestals face a random doorway direction of their room.
func _get_center_facing_rotation(room: RoomData) -> float:
	if room and not room.get_doorway_directions().is_empty():
		var directions := room.get_doorway_directions()
		var direction := directions[_rng.randi() % directions.size()] as int
		return FACE_ROTATION[direction]
	return FACE_ROTATION[WorldData.Direction.SOUTH]

### -----------------------------------------------------------------------------------------------

### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
