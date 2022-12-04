extends Particles


onready var blastradius = $"%BlastRadius"
var trigger = false

func _ready():
	pass




func _physics_process(delta):
	pass

func _on_Bomb_explosion():
	var detection_array : Array
	var collisions = blastradius.get_overlapping_bodies()
	for body in collisions:
		if body is RigidBody:
			var space = get_world().direct_space_state
			var bodies = space.intersect_ray( body.global_transform.origin,global_transform.origin) 

			if (not bodies.empty()) :
#				detection_array.append(bodies.collider)
				var distance = global_transform.origin.distance_to(bodies.collider.global_transform.origin) 
				var damage_coordinates 
				if distance > 0 :
					damage_coordinates = 1 / global_transform.origin.distance_to(bodies.collider.global_transform.origin) * get_parent().bomb_damage
				else:
					damage_coordinates = get_parent().bomb_damage
				if bodies.collider != body and  bodies.collider  is RigidBody:
					if body.is_in_group("CHARACTER"):
						body.damage(damage_coordinates,get_parent().damage_type,bodies.collider)
						body.apply_central_impulse( - body.global_transform.basis.z * damage_coordinates)
					else:
						body.apply_central_impulse( - body.global_transform.basis.z * damage_coordinates)
						
				else:
#					if ! detection_array.has(bodies.collider):
						if bodies.collider.is_in_group("CHARACTER") and bodies.collider is RigidBody:
							bodies.collider.damage(damage_coordinates,get_parent().damage_type,bodies.collider)
							bodies.collider.apply_central_impulse(- bodies.collider.global_transform.basis.z * damage_coordinates)
							print(damage_coordinates)
						elif !bodies.collider.is_in_group("CHARACTER") and bodies.collider is RigidBody:  
							bodies.collider.apply_central_impulse(- bodies.collider.global_transform.basis.z * damage_coordinates)











func _on_BlastRadius_body_entered(body):
	pass
