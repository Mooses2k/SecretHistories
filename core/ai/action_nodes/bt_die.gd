class_name BT_Die
extends BT_Node

### If character is dead, we're done processing their BehaviorTree


func tick(state : CharacterState) -> int:
	if state.character.alive == false:
		return Status.SUCCESS   # Because this is a Selector
	return Status.FAILURE   # Because this is a Selector, proceed with tree
