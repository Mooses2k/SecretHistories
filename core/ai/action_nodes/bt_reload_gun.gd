class_name BTReloadGun
extends BTNode


signal character_reloaded   # For signalling speech


func tick(state : CharacterState) -> int:
	var inventory = state.character.inventory
	var equipment = state.character.inventory.current_mainhand_equipment as GunItem

	for ammo_type in equipment.ammo_types:
		if inventory.tiny_items.has(ammo_type) and inventory.tiny_items[ammo_type] > 0:
			if equipment.current_ammo < 1:
				equipment.reload()
				emit_signal("character_reloaded")
				print(state.character, " is reloading.")
				return Status.SUCCESS
	return Status.FAILURE
