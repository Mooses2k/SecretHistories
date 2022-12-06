extends Particles


onready var blastradius = $"%BlastRadius"
var trigger = false
#export var damage_impulse : float = 250 

var space
var bodies
var damage_coordinates 
var distance
var collisions

func _physics_process(delta):
	pass

func _on_Bomb_explosion():
	collisions = blastradius.get_overlapping_bodies()
	for body in collisions:
		if body is RigidBody:
			space = get_world().direct_space_state
			bodies = space.intersect_ray( body.global_transform.origin,global_transform.origin) 

			if (not bodies.empty()) :
				distance = global_transform.origin.distance_to(bodies.collider.global_transform.origin) 
				
				if distance > 0 :
					damage_coordinates = 1 / global_transform.origin.distance_to(bodies.collider.global_transform.origin) * get_parent().bomb_damage
				else:
					damage_coordinates = get_parent().bomb_damage
				if bodies.collider != body and  bodies.collider  is RigidBody:
					if body.is_in_group("CHARACTER"):
						body.damage(damage_coordinates * 2,get_parent().damage_type,bodies.collider)
						body.apply_central_impulse( + body.global_transform.origin * 1 / global_transform.origin.distance_to(body.global_transform.origin) * get_parent().bomb_damage)
					else:
						body.apply_central_impulse( + body.global_transform.origin * 1 / global_transform.origin.distance_to(body.global_transform.origin) * get_parent().bomb_damage)
						
				else:
						if bodies.collider.is_in_group("CHARACTER") and bodies.collider is RigidBody:
							bodies.collider.damage(damage_coordinates,get_parent().damage_type,bodies.collider)
							bodies.collider.apply_central_impulse(+ bodies.collider.global_transform.origin * damage_coordinates)
							
						elif !bodies.collider.is_in_group("CHARACTER") and bodies.collider is RigidBody:  
							bodies.collider.apply_central_impulse(+ bodies.collider.global_transform.origin * damage_coordinates)










