class_name BTGunCooldown
extends BTNode

# Checks if the gun (in the mainhand) is on cooldown


func tick(state : CharacterState) -> int:
	var equipment = state.character.inventory.current_mainhand_equipment as GunItem
	if equipment:
#		if equipment.on_cooldown or equipment.is_reloading:
		if equipment.on_cooldown or state.character.is_reloading:
			return Status.RUNNING
		return Status.SUCCESS
	return Status.FAILURE
