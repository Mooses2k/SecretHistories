class_name BTIsPlayer extends BTCheck


func tick(state: CharacterState) -> int:
	if is_instance_valid(state.target):
		if state.target.object is Player and state.target.emissor is VisualSensor and state.target.interest > 200:
			return OK
	return FAILED