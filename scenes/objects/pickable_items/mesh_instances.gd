extends MeshInstance


onready var parent = get_owner()


func _ready():
	pass
# Tracking the objects state, in order to prevent clipping into walls when equipped
func _process(delta):
	if parent.get_parent().owner != null:
#		print(parent.get_parent().owner.name)
		if parent.get_parent().owner.name == "Player":
		#	if parent.mode == parent.equipped_mode:
				layers = 2
		else:
				layers = 1
			
	else:
		layers = 1

