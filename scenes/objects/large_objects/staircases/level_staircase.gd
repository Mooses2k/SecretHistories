# Write your doc string for this file here
class_name LevelStaircase
extends Node3D

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

@export var path_spawn_position := NodePath("PlayerSpawnPosition")
@export var facing_direction : WorldData.Direction = WorldData.Direction.EAST : set = _set_facing_direction

#--- private variables - order: export > normal var > onready -------------------------------------

@onready var _spawn_position := get_node(path_spawn_position) as Marker3D

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _set_facing_direction(value: int) -> void:
	facing_direction = clamp(value, 0, WorldData.Direction.DIRECTION_MAX - 1)
	var angle = _get_facing_rotation()
	rotation.y = angle


# Override this in child scenes, according to up or down staircase
func _get_facing_rotation() -> float:
	return 0.0

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
