extends Particles


onready var blastradius = $"%BlastRadius"

var trigger = false

const IMPULSE_MULTIPLIER = 1.0


func _physics_process(delta):
	pass


func _on_Bomb_explosion():
	var collisions = blastradius.get_overlapping_bodies()
	collisions.append_array(blastradius.get_overlapping_areas())
	
	# Prune duplicate collisions with the same body or area
	var collisions_unique : Dictionary = Dictionary()
	var space = get_world().direct_space_state
	for collision in collisions:
		var body = space.intersect_ray(global_translation, collision.global_translation, [owner.get_rid()], blastradius.collision_mask | 1, true, false)
		if not body.empty():
			if not collisions_unique.has(body.rid):
				collisions_unique[body.rid] = body
		var area = space.intersect_ray(global_translation, collision.global_translation, [owner.get_rid()], blastradius.collision_mask | 1, true, true)
		if not area.empty():
			if not collisions_unique.has(area.rid):
				collisions_unique[area.rid] = area
	
	# Apply impulse to knock objects away based on damage over distance
	for rid in collisions_unique.keys():
		var intersection : Dictionary = collisions_unique[rid]
		var distance = global_translation.distance_to(intersection.position) 
		var scaled_damage = owner.bomb_damage / (1 + distance)
		if intersection.collider is RigidBody:
			var body = intersection.collider as RigidBody
			body.apply_impulse(
				intersection.position - body.global_translation,
				global_translation.direction_to(intersection.position)*scaled_damage*IMPULSE_MULTIPLIER
			)
					
		# If the body has a hitbox, apply damage
		elif intersection.collider is Hitbox:
#			print("Bomb area intersected with hitbox")
			var object = intersection.collider.owner
			if is_instance_valid(object) and object.has_method("damage"):
#				print("Bomb exploded and detect a character with damage() method")
				object.damage(floor(scaled_damage), owner.damage_type, intersection.collider)
