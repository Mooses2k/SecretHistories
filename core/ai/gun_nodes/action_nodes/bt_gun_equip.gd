class_name BTEquipNextWeapon extends BTAction


# Add something to prefer ranged weapons and don't switch if there's no ammo for it


# TODO: Enable this when have a dagger or knife for the cultist as backup
#func tick(state : CharacterState) -> int:
#	var inventory = state.character.inventory
#	for i in inventory.HOTBAR_SIZE - 1:
#		var slot = (inventory.current_slot + i + 1) % inventory.HOTBAR_SIZE
#		if inventory.hotbar[slot] is GunItem:
#			inventory.current_slot = slot
#			return Status.SUCCESS
#	return Status.FAILURE # or maybe RUNNING for now?


func tick(_character: CharacterState) -> int:
	return BTResult.OK
