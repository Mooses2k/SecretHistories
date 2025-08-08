extends Node
class_name HumanoidCharacterInput


# desired (horizontal) movement vector in world space, length limited to 1.0
var movement_vector : Vector3 = Vector3.ZERO:
	set(value):
		movement_vector = value.limit_length(1.0)
var jump : bool = false
var crouch : bool = false
var sprint : bool = false
var lean_left : bool = false
var lean_right : bool = false
var lean_forward : bool = false
