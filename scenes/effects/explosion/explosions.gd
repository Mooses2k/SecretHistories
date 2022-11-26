extends Particles


onready var bombcasts = $"%bombcasts"
export var shockwave : int 
func _ready():
	pass




func _process(delta):
	pass


func _on_Bomb_explosion():
	after_effects()



func after_effects():
	for ray in bombcasts.get_children():
		if ray.is_colliding():
			var object = ray.get_collider()
			if object is RigidBody:
				object.apply_central_impulse(-ray.global_transform.basis.z*shockwave)
