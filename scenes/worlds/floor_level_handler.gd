# Write your doc string for this file here
class_name FloorLevelHandler
extends Reference

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const MAX_DISTANCE_TO_KEEP_INSTANCE = 1

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

var _floor_level: GameWorld = null
# Don't know what this will be, just keeping it here for the future
var _floor_serialized := {}

var _floor_index: int = 0

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _init(p_floor: GameWorld, p_index: int) -> void:
	_floor_level = p_floor
	_floor_index = p_index


func _to_string() -> String:
	var msg := "[FloorLevelHandler:%s]"%[get_instance_id()]
	msg += "\n\t - floor_index: %s"%[_floor_index]
	msg += "\n\t - floor_level: %s"%[_floor_level]
	msg += "\n\t - floor_serialized: %s"%[_floor_serialized]
	return msg

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

func update_floor_data(current_index: int) -> void:
	var distance := abs(current_index - _floor_index)
	
	if distance == 0:
		return
	
	if distance <= MAX_DISTANCE_TO_KEEP_INSTANCE:
		if not _floor_serialized.empty() and not is_instance_valid(_floor_level):
			_restore_floor_level()
	else:
		if _floor_serialized.empty() and is_instance_valid(_floor_level):
			_serialize_floor_level()
	
	print("Updated floor data: %s"%[self])


func get_level_instance() -> GameWorld:
	if not is_instance_valid(_floor_level):
		_restore_floor_level()
	
	return _floor_level

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _restore_floor_level() -> void:
	# Write code to deserialize level here
	pass


func _serialize_floor_level() -> void:
	# Write code to serialize level here. You'll probably want to keep the part below so just 
	# left it here from my failed attempts, if it's needed just uncomment them.
#	if _floor_level.is_inside_tree():
#		_floor_level.queue_free()
#	else:
#		_floor_level.free()
#
#	_floor_level = null
	pass

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
