class_name BTGunHasAmmo
extends BTNode


func tick(state : CharacterState) -> int:
	var equipment = state.character.inventory.current_mainhand_equipment as GunItem
	if equipment:
		if equipment.current_ammo > 0 || state.character.is_reloading:
#		if state.character.is_reloading:
#			return Status.RUNNING
#		if equipment.current_ammo > 0:
			return Status.SUCCESS
	return Status.FAILURE
