extends BTAction

func _tick(state : CharacterState) -> int:
	var current_interest = state.target
	if current_interest is BTInterestMachine.Event:
		var object = current_interest.object
		if is_instance_valid(object):
			state.interest_machine.remove_event(object)
	return BTResult.OK
