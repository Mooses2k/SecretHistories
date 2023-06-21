# Requirements for maximum size of room. Properties are expressed in single tiles.
tool
class_name RequirementMaxSize
extends RoomRequirements

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

var max_x_tiles := 1
var max_y_tiles := 1

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func has_fulfilled_requirement(room_data: RoomData) -> bool:
	var value := false
	
	value = (
			room_data.rect2.size.x <= max_x_tiles
			and room_data.rect2.size.y <= max_y_tiles
	)
	
	return value

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

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
		name = "max_x_tiles",
		type = TYPE_INT,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "1,2,1,or_greater"
	})
	
	properties.append({
		name = "max_y_tiles",
		type = TYPE_INT,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "1,2,1,or_greater"
	})
	
	return properties

### -----------------------------------------------------------------------------------------------
