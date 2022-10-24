class_name BT_Gun_Equipped
extends BT_Node


func tick(state : CharacterState) -> int:
	var equipment = state.character.inventory.current_primary_equipment as GunItem
	if equipment:
		return Status.SUCCESS
	return Status.FAILURE
