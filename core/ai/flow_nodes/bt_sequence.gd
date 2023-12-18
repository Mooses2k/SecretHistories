class_name BTSequence, "res://core/ai/phold_icons/sequence.svg" extends BTControlFlow


# If SUCCESS, continue processing any other nodes in the Sequence


func tick(state : CharacterState) -> int:
	for child in self.child_nodes_bt:
		var status = child.tick(state)
		if status != OK: return status
	return OK
