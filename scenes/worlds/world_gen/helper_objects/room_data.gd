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


# Returns an Array of Vector2 positions for the four corners of the Room, in clockwise order.
func get_corner_position_vectors() -> Array:
	var top_left := rect2.position
	var top_right := rect2.position + Vector2(rect2.size.x - 1, 0)
	var bottom_right := rect2.end - Vector2.ONE
	var bottom_left := rect2.position + Vector2(0, rect2.size.y - 1)
	var value := [top_left, top_right, bottom_right, bottom_left]
	return value

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
