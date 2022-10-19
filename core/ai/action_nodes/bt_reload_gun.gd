class_name BT_Reload_Gun
extends BT_Node

func tick(state : CharacterState) -> int:
	var equipment = state.character.inventory.current_equipment as GunItem
	if equipment:
		equipment.reload()
		return Status.SUCCESS
	return Status.FAILURE

