class_name BTFreeInterest extends BTAction


func tick(state: CharacterState) -> int:
	if !(state.target is Player):
		state.interest_machine.remove_event(state.target)
	return OK
