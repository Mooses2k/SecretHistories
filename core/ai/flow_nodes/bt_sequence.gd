class_name BTSequence, "res://core/ai/phold_icons/sequence.svg" extends BTControlFlow


# If SUCCESS, continue processing any other nodes in the Sequence


func _tick(state : CharacterState) -> int:
	for child in self.child_nodes_bt:
		var status = child.tick(state)
		if status != BTResult.OK: return status
	return BTResult.OK

#func _tick(_state : CharacterState, root : BTNode) -> int:
#	var result = BTResult.OK
#	for child in self.child_nodes_bt:
#		result = child._tick(_state, root)
#		if result != BTResult.OK: break
#	var result_string = BTResult.keys()[result]
#	var path = root.get_path_to(self)
#	print(path, " -> ", result_string)
#	return result
