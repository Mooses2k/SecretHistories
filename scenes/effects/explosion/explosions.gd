extends Particles


onready var bombcasts = $"%bombcasts"
export var shockwave : int 
export var blast_range : float
export var blast_damage : float
export(AttackTypes.Types) var damage_type : int = 0

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
				if object is RigidBody and !object.is_in_group("CHARACTER") :
					object.apply_central_impulse(-ray.global_transform.basis.z * shockwave)
				else:
					object.apply_central_impulse(-ray.global_transform.basis.z * shockwave)
					object.damage(blast_damage,damage_type,object)




func _on_Shockwave_timeout():
	after_effects()

