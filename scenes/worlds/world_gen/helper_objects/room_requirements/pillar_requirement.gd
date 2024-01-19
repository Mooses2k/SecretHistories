@tool
# Write your doc string for this file here
class_name RequirementPillar
extends RoomRequirements

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const PREVIEW_TEXT = {
	true: "Has Pillars",
	false: "No Pillars",
}

#--- public variables - order: export > normal var > onready --------------------------------------

@export var has_pillars := true: set = _set_has_pillars

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _init() -> void:
	_update_resource_name()

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func has_fulfilled_requirement(room_data: RoomData) -> bool:
	var value := has_pillars == room_data.has_pillars
	return value

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _update_resource_name() -> void:
	resource_name = PREVIEW_TEXT[has_pillars]


func _set_has_pillars(value: bool) -> void:
	has_pillars = value
	_update_resource_name()

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
