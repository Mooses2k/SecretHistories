extends GPUParticles3D


func _ready():
	self.emitting = true

func _on_Timer_timeout():
	queue_free()
	pass # Replace with function body.
