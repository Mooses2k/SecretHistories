class_name BT_Shoot
extends BT_Node


func tick(state : CharacterState) -> int:
	var equipment = state.character.inventory.current_mainhand_equipment as GunItem
	if equipment:
		equipment._use_primary()
		print("trying to shoot")
		return Status.SUCCESS
	return Status.FAILURE
