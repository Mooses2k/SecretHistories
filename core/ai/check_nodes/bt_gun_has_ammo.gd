class_name BTGunHasAmmo extends BTNode


# Checks if the currently equipped (mainhand) item has ammo loaded


func tick(state : CharacterState) -> int:
	var equipment = state.character.inventory.current_mainhand_equipment as GunItem
	if equipment and equipment.current_ammo > 0 || state.character.is_reloading:
		return OK
	return FAILED
