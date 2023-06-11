class_name BT_Selector
extends BT_ControlFlow

# If and when a node is a  SUCCESS, end Selector


func tick(state : CharacterState) -> int:
	for child in self.child_nodes_bt:
		var status = child.tick(state)
		if status != Status.FAILURE:
			return status
	return Status.FAILURE
