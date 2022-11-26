extends Particles


onready var bombcasts = $"%bombcasts"
export var shockwave : int 
export var blast_range : float

func _ready():
	pass





func _physics_process(delta):
	pass

func _on_Bomb_explosion():
	for ray in bombcasts.get_children():
		ray.enabled = true
		ray.cast_to.y = blast_range
	$Shockwave.start()


func after_effects():
		for ray in bombcasts.get_children():
			if ray.is_colliding():
				var object = ray.get_collider()
				if object is RigidBody:
					object.apply_central_impulse(-ray.global_transform.basis.z * shockwave)



func _on_Shockwave_timeout():
	after_effects()

