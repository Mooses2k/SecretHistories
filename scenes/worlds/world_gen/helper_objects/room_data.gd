# Room basic definitions, like its Rect2D for position and size, cells used, polygons, type, etc...
class_name RoomData
extends Resource

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

enum OriginalPurpose {
	EMPTY,
	CRYPT, # (1 door)
	FOUNTAIN, # (2+ doors)
	STATUE_GALLERY,
	UP_STAIRCASE,
	DOWN_STAIRCASE,
#	ENTRY, # (2x2 max, 2+ doors) 
#	ALCOVE, # (1x2 max, 1 door)
#	CHAPEL,
#	SHRINE, # (3x3 max)  
#	MEDITATION_CHAMBER, # (2x2 max, 1 door, no wall lighting)
#	MUSEUM,
#	BESTIARY,
#	RECORD_ROOM, # (3x3 min)
#	WELL # (2x2 max)
}

#enum CurrentUse{
#	UNUSED,
#	KITCHEN, # (not well)
#	PANTRY, # (3x3 max, 1 door, no wall lighting)
#	STOREROOM, # (1 door)
#	MESS_HALL, # (chooses biggest room)
#	PRIVATE_DINING_ROOM, # (3x3 max, not well)
#	GARBAGE_ROOM, # (no wall lighting) 
#	STUDY, # (3x3 max, not well)
#	LIBRARY, # (3x3 min, prefer records room)
#	TEMPLE, # (3x3 min, prefer chapel)
#	MEDITATION_CHAMBER, # (1 door, no wall lighting, prefer meditation_chamber) 
#	LOUNGE, # (not well)
#	BARRACKS, # (not well)
#	PRIVATE_BEDROOM, # (3x3 max, not well)
#	CLOSET, # (1 door, no wall lighting)
#	GUARD_POST # (2x2 max, 2+ doors)
#}
#
#export var percent_empty_original_rooms = 0.3
#export var percent_unused_current_rooms = 0.6

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

export var type := OriginalPurpose.EMPTY
export var rect2 := Rect2()
export var cell_indexes: Array
export var polygons: Array
export var has_pillars := false

#--- private variables - order: export > normal var > onready -------------------------------------

# keys are directions, and values are cell_indexes. ex:
#{ 
#	WorldData.Direction.NORTH: [57,87],
#	WorldData.Direction.WEST: [59,60],
#}
# This means that on cell indexes 57 and 87 there is a door facing NORTH
export var _doorways: Dictionary

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _init(p_type := OriginalPurpose.EMPTY, p_rect2 := Rect2()) -> void:
	var invalid_type_msg := "invalid type: %s, valid values are: %s"%[p_type, OriginalPurpose.keys()]
	assert(p_type in OriginalPurpose.values(), invalid_type_msg)
	
	type = p_type
	rect2 = p_rect2
	cell_indexes = []
	polygons = []
	has_pillars = false


func _to_string() -> String:
	var msg := "\n---- RoomData %s \n"%[get_instance_id()]
	msg += "type: %s | rect2: %s | has_pillars: %s\n"%[OriginalPurpose.keys()[type], rect2, has_pillars]
	msg += "cell_indexes: %s \n"%[cell_indexes]
	msg += "---- RoomData End %s \n"%[get_instance_id()]
	return msg

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func add_cell_index(p_cell_index) -> void:
	if not cell_indexes.has(p_cell_index):
		cell_indexes.append(p_cell_index)
	else:
		push_error("Already has p_cell_index: %s | %s"%[p_cell_index, cell_indexes])


func set_doorway_cell(cell_index: int, direction: int) -> void:
	if not _doorways.has(direction):
		_doorways[direction] = []
	
	if not _doorways[direction].has(cell_index):
		_doorways[direction].append(cell_index)
	else:
		push_warning("this doorway has already been registered.")


func can_add_doorway() -> bool:
	var value = true
	
	if (
			is_staircase_room()
			and _doorways.size() > 0
	):
		value = false
	
	return value


func get_doorway_directions() -> Array:
	return _doorways.keys()


func get_all_doorway_cells() -> Array:
	var all_doorways = []
	for direction in _doorways:
		all_doorways.append_array(_doorways[direction])
	return all_doorways


# Returns an Array with cell indexes for doorways in the asked direction. If there is none, 
# returns an empty array.
func get_doorways_for(direction: int) -> Array:
	var value = []
	
	if _doorways.has(direction):
		value = _doorways[direction].duplicate()
	
	return value


func has_doorway_on(cell_index: int, direction := -1) -> bool:
	var value := false
	
	if direction == -1:
		for doorway_indexes in _doorways.values():
			value = (doorway_indexes as Array).has(cell_index)
			if value:
				break
	else:
		if direction in _doorways:
			value = (_doorways[direction] as Array).has(cell_index)
	
	return value


func is_staircase_room() -> bool:
	var value: bool = type == OriginalPurpose.DOWN_STAIRCASE or type == OriginalPurpose.UP_STAIRCASE
	return value


# Returns whether the room's individual dimensions are both greater than on equal to
# the threshold passed in the parameter
func is_min_dimension_greater_or_equal_to(p_threshold: int) -> bool:
	var min_dimension = min(rect2.size.x, rect2.size.y)
	return min_dimension >= p_threshold


# Returns a CornerData object.
func get_corners_data() -> CornerData:
	var value := CornerData.new(rect2)
	return value

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

class CornerData extends Reference:
	const FACING_DIRECTIONS := {
		CORNER_TOP_LEFT: Vector2(-1, -1),
		CORNER_TOP_RIGHT: Vector2(1, -1),
		CORNER_BOTTOM_RIGHT: Vector2(1, 1),
		CORNER_BOTTOM_LEFT: Vector2(-1, 1)
	}
	
	var corner_positions := {}
	
	func _init(rect2: Rect2) -> void:
		corner_positions = {
			CORNER_TOP_LEFT: rect2.position,
			CORNER_TOP_RIGHT: rect2.position + Vector2(rect2.size.x - 1, 0),
			CORNER_BOTTOM_RIGHT: rect2.end - Vector2.ONE,
			CORNER_BOTTOM_LEFT: rect2.position + Vector2(0, rect2.size.y - 1)
		}
	
	
	func get_facing_angle_for(corner_type: int) -> float:
		var value := 0.0
		if corner_type in FACING_DIRECTIONS:
			value = (FACING_DIRECTIONS[corner_type] as Vector2).angle()
		else:
			push_error("Invalid corner_type: %s"%[corner_type])
		
		return value
