extends Tree

var node_to_view : Dictionary = {}

@export var success_color : Color = Color.FOREST_GREEN
@export var running_color : Color = Color.DARK_GOLDENROD
@export var failed_color : Color = Color.RED
@export var skip_color : Color = Color.DARK_GRAY


func initialize_tree(root_node : BTNode):
	clear()
	var root_item = create_item()

func clear_debug_view():
	clear()
	node_to_view.clear()



func create_tree_item_for_node(node : BTNode, parent : TreeItem) -> TreeItem:
	var tree_item : TreeItem = create_item(parent)
	tree_item.set_text(0, node.name)
	return tree_item
