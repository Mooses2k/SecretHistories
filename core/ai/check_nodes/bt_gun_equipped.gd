class_name BTGunEquipped
extends BTNode


func tick(state : CharacterState) -> int:
	var equipment = state.character.inventory.current_mainhand_equipment as GunItem
	if equipment:
		return Status.SUCCESS
	return Status.FAILURE
