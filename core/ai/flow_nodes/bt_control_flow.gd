class_name BT_ControlFlow
extends BT_Node


var child_nodes_bt = Array()


func _ready():
	_get_children_nodes()


func _get_children_nodes():
	child_nodes_bt.clear()
	for child in self.get_children():
		if child is BT_Node:
			child_nodes_bt.push_back(child)
