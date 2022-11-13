extends MeshInstance

export (NodePath) var main_parent
onready var parent = get_node(main_parent)
func _ready():
	pass


func _process(delta):
	if parent.mode == parent.equipped_mode:
		layers = 2
	else:
		layers = 1


