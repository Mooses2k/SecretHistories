@tool
class_name DecorateRooms
extends Node

## Centralized utility library for room decoration and object placement
## Contains placement utilities and decoration tags for room generation
## Consolidates functionality from room_placement_utils.gd

### Member Variables and Dependencies -------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------
const RoomWalls = preload("res://scenes/worlds/world_gen/helper_objects/crypt_room_walls.gd")

#--- enums ----------------------------------------------------------------------------------------

enum PlacementTags {
# tags for objects:
	CENTERPIECE, # looks best near center of room, wall, surface, etc
	CORNERPIECE, # looks best in a corner
	BACK_AGAINST_WALL, # only place with back to wall
	BACK_AGAINST_SIMILAR, # looks fine if put back-to-back with something similar height
	PAIRED, # symmetrical with another item across the room?
# parts of a room
	FLOOR, # typically found on a floor
	WALL, # typically found on or hung from a wall
	CEILING, # typically found on or hung from a ceiling
	MOULDING, # a strip of material used to cover transitions between surfaces or for decoration
	BASEBOARD, # aka 'skirting', type of moulding conceals junction of an interior wall and floor
	CORNICE, # type of moulding connects wall to ceiling, maybe used to direct water away from wall
	DOORWAY, # found on or in a doorway, like an engraving or part of a door latch
	DOOR, # is on a door or part of a door
	DOOR_HANDLE,
	KEYHOLE, # found in a keyhole
	PIT, # type of trap or otherwise a hole in the ground
# other furniture
	SHELVING,
	FOUNTAIN, # fonts and fountains; large, bowl-like containers of liquid that may also spit that liquid into the bowl
	WELL, # deep hole leading to liquid
# characters can lay on these
	BED,
	BUNKBED,
# other factors
	MAKES_SMOKE # larger fire that will smoke up a place if not vented
}

#--- public variables - order: export > normal var > onready --------------------------------------

#@export var place_first = false # important for room; any of these are placed before other things
#@export var must_have = false # if this isn't there at the end, regenerate the room

### Public Static Utility Methods -----------------------------------------------------------------

## Calculate remaining rectangle after accounting for wall segments
static func get_remaining_rect(room: RoomData, walls_data: RoomWalls, object_size: Vector2) -> Rect2:
	var value := room.rect2
	for direction in walls_data.cells:
		var segments := walls_data.cells[direction] as Array

		match direction:
			WorldData.Direction.NORTH:
				if segments.is_empty():
					value.position.y += 1
					value.size.y -= 1
				else:
					value.position.y += object_size.y
					value.size.y -= object_size.y
			WorldData.Direction.WEST:
				if segments.is_empty():
					value.position.x += 1
					value.size.x -= 1
				else:
					value.position.x += object_size.x
					value.size.x -= object_size.x
			WorldData.Direction.SOUTH:
				if segments.is_empty():
					value.size.y -= 1
				else:
					value.size.y -= object_size.y
			WorldData.Direction.EAST:
				if segments.is_empty():
					value.size.x -= 1
				else:
					value.size.x -= object_size.x

	return value


## Calculate center position for an object in remaining space
static func calculate_center_position(
		remaining_rect: Rect2,
		object_size: Vector2,
		cell_size: float
	) -> Dictionary:
	var object_rect := Rect2(Vector2.ZERO, object_size)
	object_rect.position = remaining_rect.position
	object_rect.position += remaining_rect.size / 2.0 - object_rect.size / 2.0

	var offset := Vector3(
		object_rect.size.x / 2.0 * cell_size,
		0,
		object_rect.size.y / 2.0 * cell_size
	)

	# Handle fractional positions - floor the position but don't expand rect for center placement
	# The rect expansion was designed for wall placement, not center placement
	if snappedf(object_rect.position.x, 1.0) != object_rect.position.x:
		object_rect.position.x = floor(object_rect.position.x)

	if snappedf(object_rect.position.y, 1.0) != object_rect.position.y:
		object_rect.position.y = floor(object_rect.position.y)

	return {
		"rect": object_rect,
		"offset": offset
	}


## Get cells for center placement
static func get_center_cells(world_data: WorldData, placement_rect: Rect2) -> Array:
	var cells := []

	for offset_x in placement_rect.size.x:
		var x := (placement_rect.position.x + offset_x) as float
		for offset_y in placement_rect.size.y:
			var y := (placement_rect.position.y + offset_y) as float
			var cell_index := world_data.get_cell_index_from_int_position(x, y)
			cells.append(cell_index)
			if not world_data.is_cell_free(cell_index):
				cells.clear()
				return cells

	return cells


## Calculate rotation based on wall direction
static func calculate_rotation(
		walls_data: RoomWalls,
		vertical_center_rotation: float
	) -> float:
	var rotation := 0.0
	if not walls_data.main_walls.is_empty():
		var main_wall = walls_data.main_walls[0]
		if main_wall == WorldData.Direction.EAST or main_wall == WorldData.Direction.WEST:
			rotation = deg_to_rad(vertical_center_rotation)
	return rotation


## Validate if object fits in remaining space
static func can_place_object(remaining_rect: Rect2, object_size: Vector2) -> bool:
	return remaining_rect.size >= object_size


## Get all cells for a wall segment
static func get_cells_for_wall_segment(
		world_data: WorldData,
		segment: Array,
		direction: int,
		tile_size: Vector2
	) -> Array:
	var width_direction := world_data.direction_inverse(direction)
	var cells := []

	for cell_index in segment:
		cells.append(cell_index)
		for _width in tile_size.y - 1:
			cell_index = world_data.get_neighbour_cell(cell_index, width_direction)
			cells.append(cell_index)

	return cells


## Calculate offset for wall placement
static func get_wall_offset(direction: int, surplus_cells: int) -> Vector3:
	var center_offset := surplus_cells / 2.0
	match direction:
		WorldData.Direction.NORTH, WorldData.Direction.SOUTH:
			return Vector3(center_offset, 0, 0)
		WorldData.Direction.EAST, WorldData.Direction.WEST:
			return Vector3(0, 0, center_offset)
	return Vector3.ZERO


## Create spawn data for object placement
static func create_spawn_data(
		data: WorldData,
		scene_path: String,
		first_cell: int,
		offset: Vector3,
		rotation: float,
		custom_properties: Dictionary = {}
	) -> SpawnData:
	var spawn_data := SpawnData.new()
	spawn_data.scene_path = scene_path

	var spawn_position = data.get_local_cell_position(first_cell) + offset
	spawn_data.set_position_in_cell(spawn_position)
	spawn_data.set_y_rotation(rotation)

	for property_name in custom_properties:
		spawn_data.set_custom_property(property_name, custom_properties[property_name])

	return spawn_data


## Process wall segments for object placement
static func process_wall_segments(
		world_data: WorldData,
		walls_data: RoomWalls,
		direction: int,
		tile_size: Vector2,
		callback: Callable
	) -> void:
	var segments := walls_data.get_sanitized_segments_for(world_data, direction, tile_size)
	for value in segments:
		var segment := value as Array
		var surplus_cells := segment.size() % int(tile_size.x)

		if surplus_cells == 0:
			for index in range(0, segment.size(), tile_size.x):
				var slice = segment.slice(index, index + tile_size.x)
				var cells := get_cells_for_wall_segment(world_data, slice, direction, tile_size)
				callback.call(cells, direction)
		else:
			var cells := get_cells_for_wall_segment(world_data, segment, direction, tile_size)
			var wall_offset := get_wall_offset(direction, surplus_cells) * world_data.CELL_SIZE
			callback.call(cells, direction, wall_offset)

### Built-in Virtual Overrides --------------------------------------------------------------------
