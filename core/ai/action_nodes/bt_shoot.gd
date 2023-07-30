class_name BT_Shoot
extends BT_Node


signal fighting


func tick(state : CharacterState) -> int:
	var speech_chance = randf()
	var equipment = state.character.inventory.current_mainhand_equipment as GunItem
	if equipment:
		if (speech_chance > 0.75):
			emit_signal("fighting")
		print("Cultist trying to shoot")
		equipment._use_primary()
		return Status.SUCCESS
	return Status.FAILURE
