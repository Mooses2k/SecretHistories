class_name BT_Gun_Has_Ammo
extends BT_Node


func tick(state : CharacterState) -> int:
	var equipment = state.character.inventory.current_primary_equipment as GunItem
	if equipment:
		if equipment.current_ammo > 0 || equipment.is_reloading:
			return Status.SUCCESS
	return Status.FAILURE
