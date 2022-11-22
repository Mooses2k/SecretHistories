class_name BT_Equip_Next_Gun
extends BT_Node


func tick(state : CharacterState) -> int:
	var inventory = state.character.inventory
	for i in inventory.HOTBAR_SIZE - 1:
		var slot = (inventory.current_slot + i + 1)%inventory.HOTBAR_SIZE
		if inventory.hotbar[slot] is GunItem:
			inventory.current_slot = slot
			return Status.SUCCESS
	return Status.FAILURE
