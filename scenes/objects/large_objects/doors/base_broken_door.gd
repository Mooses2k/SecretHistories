extends Node3D


# Declare member variables here. Examples:
# var a: int = 2
# var b: String = "text"

func apply_impulse(position : Vector3, impulse : Vector3, decay : float):
	for _rb in get_children():
		var rb : RigidBody3D = _rb as RigidBody3D
		if (not is_instance_valid(rb)):
			continue
		var offset : Vector3 = position - rb.global_position
		var distance : float = offset.length()
		var attenuation = 1.0/(1.0 + pow(distance, decay))
		rb.apply_impulse(impulse*attenuation, offset)
