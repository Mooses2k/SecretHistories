class_name BTControlFlow
extends BTNode


var child_nodes_bt = Array()


func _ready():
	_get_children_nodes()


func _get_children_nodes():
	child_nodes_bt.clear()
	for child in self.get_children():
		if child is BTNode:
			child_nodes_bt.push_back(child)
