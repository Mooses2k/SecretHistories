class_name BTShoot extends BTAction

# Attempts to shoot the gun equipped (in the mainhand)


signal fighting   # For signalling speech


func _tick(state : CharacterState) -> int:
	var speech_chance = randf()
	var equipment = state.character.inventory.current_mainhand_equipment as GunItem
	if equipment:
		if (speech_chance > 0.75):
			emit_signal("fighting")
#		TODO disable shooting for now
#		print("Pew")
		equipment._use_primary()
		return BTResult.OK
	return BTResult.FAILED
