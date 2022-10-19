extends EquipmentItem
class_name PadlockItem

export var padlock_id : int = 0
export var padlock_locked : bool = false

var loop_position : Vector3 setget ,get_loop_position

func get_loop_position() -> Vector3:
	return $LoopPosition.translation

func _use():
	print("padlock used")
	
	
