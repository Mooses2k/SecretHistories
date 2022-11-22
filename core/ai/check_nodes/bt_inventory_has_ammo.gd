class_name BT_Inventory_Has_Ammo
extends BT_Node


func tick(state : CharacterState) -> int:
	var inventory = state.character.inventory
	var equipment = inventory.current_mainhand_equipment as GunItem
	if equipment:
		for ammo_type in equipment.ammo_types:
			if inventory.tiny_items.has(ammo_type) and inventory.tiny_items[ammo_type] > 0:
				return Status.SUCCESS
	return Status.FAILURE
