class_name BTGunEquipped extends BTCheck


# Checks if a gun is equipped (in the mainhand)


func tick(state : CharacterState) -> int:
	return BTResult.OK if state.character.inventory.current_mainhand_equipment is GunItem else BTResult.FAILED
