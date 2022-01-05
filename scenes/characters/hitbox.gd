extends Area
class_name Hitbox

export var hitbox_owner_path : NodePath

onready var character = owner

func hit(damage : int, type : int = AttackTypes.Types.PHYSICAL, _position : Vector3 = Vector3.ZERO, _direction : Vector3 = Vector3.ZERO):
	character.damage(damage, type)
