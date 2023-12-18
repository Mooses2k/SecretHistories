class_name BTControlFlow extends BTNode

# Build a list of all hehavior tree nodes for this character at spawntime.

var child_nodes_bt := Array()

func _ready() -> void:
	_get_children_nodes()

func _get_children_nodes() -> void:
	child_nodes_bt.clear()

	for child in self.get_children(): if child is BTNode:
		child_nodes_bt.push_back(child)
