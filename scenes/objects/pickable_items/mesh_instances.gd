extends MeshInstance


onready var parent = get_owner()


# Tracking the objects state, in order to prevent clipping into walls when equipped
func _process(delta):
	if parent.mode == parent.equipped_mode:

		layers = 2
	else:
		layers = 1
