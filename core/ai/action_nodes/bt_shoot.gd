class_name BT_Shoot
extends BT_Node

export var gun : NodePath
onready var _gun : Gun = get_node(gun) as Gun

func tick(state : CharacterState) -> int:
	if _gun.can_shoot():
		_gun.shoot()
		return Status.SUCCESS
	return Status.FAILURE

