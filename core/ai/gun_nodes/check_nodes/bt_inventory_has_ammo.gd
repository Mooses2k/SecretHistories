class_name BTInventoryHasAmmo extends BTCheck


# Checks if character has ammo for the currently equipped (mainhand) item


func tick(state : CharacterState) -> int:
	var inventory = state.character.inventory
	var equipment := inventory.current_mainhand_equipment as GunItem
	
	if equipment: for ammo_type in equipment.ammo_types:
		return BTResult.FAILED
	return BTResult.OK
