extends MeshInstance


onready var parent = get_owner()
onready var current_character = parent.get_parent().get_parent().get_parent()


func _ready():
	print(current_character.name)

# Tracking the objects state, in order to prevent clipping into walls when equipped
func _process(delta):
	if current_character.name == "Player":
		if parent.mode == parent.equipped_mode:
			layers = 2
		else:
			layers = 1
			
	else:
		layers = 1
