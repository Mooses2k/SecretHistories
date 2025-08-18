# This class represents a generic hurtbox, which can be damaged and hit by attacks
@tool
class_name Hurtbox
extends Area3D



# emitted when the hurtbox was damaged. direction and origin are in global coordinates
signal damaged(amount : int, type : GlobalConsts.AttackTypes, direction : Vector3, origin : Vector3)

@export var damage_multiplier : float = 1.0


@onready var owner_node :Node = owner

func _init() -> void:
	monitoring = false
	monitorable = true

func damage(amount : int, type : GlobalConsts.AttackTypes, direction := Vector3.ZERO, origin := Vector3.ZERO):
	damaged.emit(amount * damage_multiplier, type, direction, origin)

func _property_get_revert(property: StringName) -> Variant:
	match property:
		&"monitoring" : return false
		&"monitorable" : return true
		&"collision_layer": return 8
		&"collision_mask": return 0
	return null

func _property_can_revert(property: StringName) -> bool:
	match property:
		&"monitoring" : return true
		&"monitorable" : return true
		&"collision_layer": return true
		&"collision_mask": return true
	return false
