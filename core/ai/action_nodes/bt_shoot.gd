class_name BT_Shoot
extends BT_Node


func tick(state : CharacterState) -> int:
	var equipment = state.character.inventory.current_primary_equipment as GunItem
	if equipment:
		equipment.use()
		return Status.SUCCESS
	return Status.FAILURE
