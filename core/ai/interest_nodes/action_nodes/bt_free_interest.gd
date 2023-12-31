class_name BTFreeInterest extends BTAction


func _tick(state: CharacterState) -> int:
	if !is_instance_valid(state.target):
		return BTResult.FAILED
	
	if !(state.target.object is Player):
		state.interest_machine.remove_event(state.target)
	
	return BTResult.OK
