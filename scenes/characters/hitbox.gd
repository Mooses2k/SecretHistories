extends Area
class_name Hitbox

export var hitbox_owner_path : NodePath

onready var character : Character = get_node(hitbox_owner_path) as Character

func hit(damage : int, type : int = AttackTypes.Types.PHYSICAL, position : Vector3 = Vector3.ZERO, direction : Vector3 = Vector3.ZERO):
	character.damage(damage, type)
