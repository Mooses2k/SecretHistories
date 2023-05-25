extends Particles


var ready : bool = false


func _ready():
	ready = true
	self.set_as_toplevel(true)
	self.emitting = true
	# choose material type then play sound, for now, always a neutral thud
	$Sounds/Stone.play()


func set_orientation(position : Vector3, normal : Vector3):
	if not ready:
		yield(self, "ready")
	self.global_transform.origin = position
	if not normal.is_equal_approx(Vector3.ZERO) and not normal.is_equal_approx(Vector3.UP):
		self.look_at(normal + position, Vector3.UP)


func _on_Timer_timeout():
	queue_free()
