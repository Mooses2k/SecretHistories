# Room basic definitions, like its Rect2D for position and size, cells used, polygons, type, etc...
class_name RoomData
extends Resource

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

export var type := ""
export var rect2 := Rect2()
export var cell_indexes: Array
export var polygons: Array
export var pillars: Array

#--- private variables - order: export > normal var > onready -------------------------------------

func _init(p_type := "", p_rect2 := Rect2()) -> void:
	type = p_type
	rect2 = p_rect2
	cell_indexes = []
	polygons = []
	pillars = []

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _to_string() -> String:
	var msg := "\n---- RoomData %s \n"%[get_instance_id()]
	msg += "type: %s | rect2: %s \n"%[type, rect2]
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


# Returns whether the room's individual dimensions are both greater than on equal to
# the threshol passed in the parameter
func is_min_dimension_greater_or_equal_to(p_threshold: int) -> bool:
	var min_dimension = min(rect2.size.x, rect2.size.y)
	return min_dimension >= p_threshold


# Returns a CornerData object.
func get_corner_position_vectors() -> CornerData:
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
