class_name BT_Gun_Cooldown
extends BT_Node

export var gun : NodePath
onready var _gun : Gun = get_node(gun) as Gun

func tick(state : CharacterState) -> int:
	if _gun.can_shoot():
		return Status.SUCCESS
	return Status.RUNNING
