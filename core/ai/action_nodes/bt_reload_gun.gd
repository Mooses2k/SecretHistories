class_name BT_Reload_Gun
extends BT_Node


func tick(state : CharacterState) -> int:
	var equipment = state.character.inventory.current_mainhand_equipment as GunItem
	print(equipment)
	if equipment:
		print("Cultist reloading")
		equipment.reload()
		return Status.SUCCESS
	print("Cultist didn't reload successfully?")
	return Status.FAILURE
