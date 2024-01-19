class_name PadlockItem
extends EquipmentItem


@export var padlock_id : int = 0
@export var padlock_locked : bool = false

var loop_position : Vector3: get = get_loop_position


func get_loop_position() -> Vector3:
	return $LoopPosition.position


func _use():
	print("padlock used")
