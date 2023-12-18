class_name BTShouldShootTarget extends BTCheck


export var interest_threshold := 100.0


func tick(state: CharacterState) -> int:
	return OK if state.target is Player and state.target.interest > interest_threshold else FAILED