extends Spatial


# Declare member variables here. Examples:
# var a: int = 2
# var b: String = "text"

func apply_impulse(position : Vector3, impulse : Vector3, decay : float):
	for _rb in get_children():
		var rb : RigidBody = _rb as RigidBody
		if (not is_instance_valid(rb)):
			continue
		var offset : Vector3 = position - rb.global_translation
		var distance : float = offset.length()
		var attenuation = 1.0/(1.0 + pow(distance, decay))
		rb.apply_impulse(offset, impulse*attenuation)
