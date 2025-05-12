@tool
class_name Hurtbox
extends Area3D


# This class represents a generic hurtbox, which can be damage and hit by attacks

# emitted when the hurtbox was damaged. direction and origin are in global coordinates
signal damaged(amount : int, type : GlobalConsts.AttackTypes, direction : Vector3, origin : Vector3)

func _init() -> void:
	monitoring = false
	monitorable = true

func damage(amount : int, type : GlobalConsts.AttackTypes, direction := Vector3.ZERO, origin := Vector3.ZERO):
	damaged.emit(amount, type, direction, origin)

func _property_get_revert(property: StringName) -> Variant:
	match property:
		&"monitoring" : return false
		&"monitorable" : return true
	return null

func _property_can_revert(property: StringName) -> bool:
	match property:
		&"monitoring" : return true
		&"monitorable" : return true
	return false
