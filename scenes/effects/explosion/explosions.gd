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
			var bodies = space.intersect_ray(global_transform.origin, body.global_transform.origin) 
			if (not bodies.empty()) :
				if ! detection_array.has(bodies.collider):
					detection_array.append(bodies.collider)
					var distance = global_transform.origin.distance_to(bodies.collider.global_transform.origin) 
					var direction_vector = global_transform.origin - bodies.collider.global_transform.origin
					var damage_coordinates 
					if distance > 0 :
						damage_coordinates = 1 / global_transform.origin.distance_to(bodies.collider.global_transform.origin) * get_parent().bomb_damage
					else:
						damage_coordinates = get_parent().bomb_damage
					if bodies.collider.is_in_group("CHARACTER"):
						bodies.collider.damage(damage_coordinates,get_parent().damage_type,bodies.collider)
						bodies.collider.apply_central_impulse( -bodies.position * damage_coordinates)
					else:
						bodies.collider.apply_central_impulse( -bodies.position  * damage_coordinates)











func _on_BlastRadius_body_entered(body):
	pass
