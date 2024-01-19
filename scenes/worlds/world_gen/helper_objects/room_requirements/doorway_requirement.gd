@tool
# Write your doc string for this file here
class_name RequirementDoorways
extends RoomRequirements

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

@export var min_doorways := 1: set = _set_min_doorways
@export var max_doorways := 1: set = _set_max_doorways

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _init() -> void:
	_update_resource_name()

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func has_fulfilled_requirement(room_data: RoomData) -> bool:
	var doorway_direction_count := room_data.get_doorway_directions().size()
	var value = true
	if doorway_direction_count < min_doorways or doorway_direction_count > max_doorways:
		value = false
	return value

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _update_resource_name() -> void:
	if min_doorways == max_doorways:
		resource_name = "%s Doorways"%[min_doorways]
	else:
		resource_name = "%s~%s Doorways"%[min_doorways, max_doorways]


func _set_min_doorways(value: int) -> void:
	min_doorways = clamp(value, 1, max_doorways)
	_update_resource_name()


func _set_max_doorways(value: int) -> void:
	max_doorways = max(value, min_doorways)
	_update_resource_name()

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
