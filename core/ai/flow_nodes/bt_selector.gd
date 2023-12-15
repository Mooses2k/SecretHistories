class_name BTSelector, "res://core/ai/phold_icons/selector.svg" extends BTControlFlow


# If and when a node is a SUCCESS, end Selector.


func tick(state : CharacterState) -> int:
	for child in self.child_nodes_bt:
		var status = child.tick(state)
		if status != FAILED:
			return status
	return FAILED
