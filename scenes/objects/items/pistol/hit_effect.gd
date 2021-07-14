extends Particles


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


var ready : bool = false
func _ready():
	ready = true
	self.set_as_toplevel(true)
	self.emitting = true
	pass # Replace with function body.

func set_orientation(position : Vector3, normal : Vector3):
	if not ready:
		yield(self, "ready")
	self.global_transform.origin = position
	self.look_at(normal + position, Vector3.UP)


func _on_Timer_timeout():
	queue_free()
	pass # Replace with function body.
