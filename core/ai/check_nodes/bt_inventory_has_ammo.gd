class_name BTInventoryHasAmmo extends BTNode


# Checks if character has ammo for the currently equipped (mainhand) item


func tick(state : CharacterState) -> int:
	var inventory = state.character.inventory
	var equipment = inventory.current_mainhand_equipment as GunItem
	if equipment:
		for ammo_type in equipment.ammo_types:
			return FAILED   # Fails because this is a selector, fail means check next item
	return OK
