class_name BTNode extends Node


enum BTResult {
	OK,
	FAILED,
	RUNNING,
	SKIP,
}


func tick(_state : CharacterState) -> int:
	return BTResult.FAILED

func _tick(_state : CharacterState, root : BTNode) -> int:
	var result = tick(_state)
	var result_string = BTResult.keys()[result]
	var node_state = _get_node_state()
	var path = root.get_path_to(self)
	print(path, " -> ", result_string, " ", node_state)
	return result

func _get_node_state() -> Dictionary:
	return {}
