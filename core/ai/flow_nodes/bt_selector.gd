class_name BTSelector, "res://core/ai/phold_icons/selector.svg" extends BTControlFlow

# If and when a node is a SUCCESS, end Selector.


func _tick(state : CharacterState) -> int:
	for child in self.child_nodes_bt:
		var status = child.tick(state)
		if status != BTResult.FAILED:
			return status
	return BTResult.FAILED


#func _tick(_state : CharacterState, root : BTNode) -> int:
#	var result = BTResult.OK
#	for child in self.child_nodes_bt:
#		result = child._tick(_state, root)
#		if result != BTResult.FAILED:
#			break
#	var result_string = BTResult.keys()[result]
#	var path = root.get_path_to(self)
#	print(path, " -> ", result_string)
#	return result
