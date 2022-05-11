extends Area
class_name Hitbox

export var hitbox_owner_path : NodePath

onready var character = owner

var can_hit := false
var damage := 0
var type: int = AttackTypes.Types.SLASHING

func set_info(idamage : int, itype : int = AttackTypes.Types.PHYSICAL, _position : Vector3 = Vector3.ZERO, _direction : Vector3 = Vector3.ZERO):
	damage = idamage
	type = itype

func hit(character):
	if !can_hit: return
	
	print(character)
	if character.is_in_group("CHARACTER"):
		character.owner.damage(damage, type)
	
