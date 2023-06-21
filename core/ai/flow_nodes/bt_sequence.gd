class_name BT_Sequence
extends BT_ControlFlow

# If SUCCESS, continue processing any other nodes in the Sequence


func tick(state : CharacterState) -> int:
	for child in self.child_nodes_bt:
		var status = child.tick(state)
		if status != Status.SUCCESS:
			return status
	return Status.SUCCESS
