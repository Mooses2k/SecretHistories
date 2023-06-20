# Generic resource that defines the rules for a room to fit a certain purpose
tool
class_name RoomPurpose
extends Resource

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

export var purpose_id := ""

# a value of 0 means "unlimited"
var max_amount := 0
var requirements := []

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func is_compatible(room_data: RoomData) -> bool:
	var value = false
	
	for item in requirements:
		var requirement := item as RoomRequirements
		if requirement == null:
			continue
		
		value = requirement.has_fulfilled_requirement(room_data)
		if value == false:
			break
	
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
		name = "max_amount",
		type = TYPE_INT,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,1,1,or_greater"
	})
	
	properties.append({
		name = "requirements",
		type = TYPE_ARRAY,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
		hint = PROPERTY_HINT_RESOURCE_TYPE,
		hint_string = "%s/%s:Resource"%[TYPE_OBJECT, TYPE_OBJECT]
	})
	
	return properties

### -----------------------------------------------------------------------------------------------
