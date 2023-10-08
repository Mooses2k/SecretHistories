class_name BTInventoryHasAmmo
extends BTNode

# Checks if character has ammo for the currently equipped (mainhand) item


func tick(state : CharacterState) -> int:
	var inventory = state.character.inventory
	var equipment = inventory.current_mainhand_equipment as GunItem
	if equipment:
		for ammo_type in equipment.ammo_types:
#			if inventory.tiny_items.has(ammo_type) and inventory.tiny_items[ammo_type] > 0:
#				print("Cultist's inventory has relevant ammo: ", inventory.tiny_items[ammo_type])
			return Status.FAILURE   # Fails because this is a selector, fail means check next item
#		return Status.RUNNING
	return Status.SUCCESS
