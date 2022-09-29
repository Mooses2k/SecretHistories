extends Particles

#unchecked local cords to fix following issue
func _ready():
	local_coords=false
	self.emitting = true

func _on_Timer_timeout():
	queue_free()
	pass # Replace with function body.
