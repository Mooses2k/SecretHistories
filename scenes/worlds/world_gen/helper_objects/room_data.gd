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

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func add_cell_index(p_cell_index) -> void:
	if not cell_indexes.has(p_cell_index):
		cell_indexes.append(p_cell_index)
	else:
		push_error("Already has p_cell_index: %s | %s"%[p_cell_index, cell_indexes])


func is_min_dimension_greater_or_equal_to(p_threshold: int) -> bool:
	var min_dimension = min(rect2.size.x, rect2.size.y)
	return min_dimension >= p_threshold

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
