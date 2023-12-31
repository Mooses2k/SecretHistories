class_name BTDie extends BTAction

### If character is dead, we're done processing their BehaviorTree
# This may not be needed, as we have a signal that deletes the whole tree on death

func _tick(state : CharacterState) -> int:
	if state.character.alive == false:
		return BTResult.OK # Because this is a Selector
	return BTResult.FAILED # Because this is a Selector, proceed with tree
