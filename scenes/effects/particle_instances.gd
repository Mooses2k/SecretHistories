class_name ParticleInstanceLayered
extends GPUParticles3D


@onready var parent = get_owner()


# Tracking the object's state in order to prevent clipping into walls when equipped
func _process(delta):
	if parent.get_parent().owner != null:
		if parent.get_parent().owner.name == "Player":
		#	if parent.mode == parent.equipped_mode:
				layers = 2
		else:
				layers = 1
			
	else:
		layers = 1
