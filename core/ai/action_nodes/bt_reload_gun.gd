class_name BT_Reload_Gun
extends BT_Node


signal character_reloaded   # For signalling speech


func tick(state : CharacterState) -> int:
	var equipment = state.character.inventory.current_mainhand_equipment as GunItem
	if equipment:
		equipment.reload()
		emit_signal("character_reloaded")
		return Status.SUCCESS
	return Status.FAILURE
