class_name BT_Selector
extends BT_ControlFlow


func tick(state : CharacterState) -> int:
	for child in self.child_nodes_bt:
		var status = child.tick(state)
		if status != Status.FAILURE:
			return status
	return Status.FAILURE
