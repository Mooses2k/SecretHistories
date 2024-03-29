# Requirements for minimum size of room. Properties are expressed in single tiles.
tool
class_name RequirementMinSize
extends RoomRequirements

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const EDITOR_NAME_PREVIEW = "Min Size %sx%s"

#--- public variables - order: export > normal var > onready --------------------------------------

var min_x_tiles := 0 setget _set_min_x_tiles
var min_y_tiles := 0 setget _set_min_y_tiles

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _init() -> void:
	_update_resource_name()

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func has_fulfilled_requirement(room_data: RoomData) -> bool:
	var value := false
	
	value = (
			room_data.rect2.size.x >= min_x_tiles
			and room_data.rect2.size.y >= min_y_tiles
	)
	
	return value

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _update_resource_name() -> void:
	resource_name = EDITOR_NAME_PREVIEW%[min_x_tiles, min_y_tiles]


func _set_min_x_tiles(value: int) -> void:
	min_x_tiles = value
	_update_resource_name()


func _set_min_y_tiles(value: int) -> void:
	min_y_tiles = value
	_update_resource_name()

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

###################################################################################################
# Editor Methods ##################################################################################
###################################################################################################

### Custom Inspector built in functions -----------------------------------------------------------

func _get_property_list() -> Array:
	var properties: = []
	
	properties.append({
		name = "min_x_tiles",
		type = TYPE_INT,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,1,1,or_greater"
	})
	
	properties.append({
		name = "min_y_tiles",
		type = TYPE_INT,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,1,1,or_greater"
	})
	
	return properties

### -----------------------------------------------------------------------------------------------
