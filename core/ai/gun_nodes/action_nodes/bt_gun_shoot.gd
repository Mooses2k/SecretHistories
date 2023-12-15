class_name BTShoot extends BTAction

# Attempts to shoot the gun equipped (in the mainhand)


signal fighting   # For signalling speech


func tick(state : CharacterState) -> int:
	var speech_chance = randf()
	var equipment = state.character.inventory.current_mainhand_equipment as GunItem
	if equipment:
		if (speech_chance > 0.75):
			emit_signal("fighting")
		equipment._use_primary()
		return OK
	return FAILED
