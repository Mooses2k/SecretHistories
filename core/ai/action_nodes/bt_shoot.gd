class_name BT_Shoot
extends BT_Node


func tick(state : CharacterState) -> int:
	var equipment = state.character.inventory.current_mainhand_equipment as GunItem
	if equipment:
		print("Cultist trying to shoot")
		equipment._use_primary()
		return Status.SUCCESS
	return Status.FAILURE
