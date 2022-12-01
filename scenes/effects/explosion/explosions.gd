extends Particles


onready var blastradius = $"%BlastRadius"
export var shockwave : int 
export var blast_damage : float
var trigger = false
export(AttackTypes.Types) var damage_type : int = 0

func _ready():
	pass





func _physics_process(delta):
	pass

func _on_Bomb_explosion():
	var collisions = blastradius.get_overlapping_bodies()
	for body in collisions:
		if body is RigidBody:
			var space = get_world().direct_space_state
			var bodies = space.intersect_ray(global_transform.origin, body.global_transform.origin) 
			if (not bodies.empty()) :
				if bodies.collider is RigidBody:
					if bodies.collider.is_in_group("CHARACTER"):
						bodies.collider.damage(blast_damage,damage_type,bodies.collider)
						bodies.collider.apply_central_impulse(-bodies.position  * 2)
					else:
						bodies.collider.apply_central_impulse(-bodies.position * shockwave)








func _on_BlastRadius_body_entered(body):
	pass
