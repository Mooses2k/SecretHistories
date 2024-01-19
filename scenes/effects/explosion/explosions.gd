extends GPUParticles3D


@onready var blastradius = %BlastRadius

var trigger = false

const IMPULSE_MULTIPLIER = 1.0


func _physics_process(delta):
	pass


func _on_Bomb_explosion():
	var collisions = blastradius.get_overlapping_bodies()
	collisions.append_array(blastradius.get_overlapping_areas())
	
	# Prune duplicate collisions with the same body or area
	var collisions_unique : Dictionary = Dictionary()
	var space = get_world_3d().direct_space_state
	for collision in collisions:
		var raycast_params := PhysicsRayQueryParameters3D.new()
		raycast_params.from = global_position
		raycast_params.to = collision.global_position
		raycast_params.exclude = [owner.get_rid()]
		raycast_params.collision_mask = blastradius.collision_mask | 1
		raycast_params.collide_with_bodies = true
		raycast_params.collide_with_areas = false
		var body = space.intersect_ray(raycast_params)
		if not body.is_empty():
			if not collisions_unique.has(body.rid):
				collisions_unique[body.rid] = body
		raycast_params.collide_with_areas = true
		var area = space.intersect_ray(raycast_params)
		if not area.is_empty():
			if not collisions_unique.has(area.rid):
				collisions_unique[area.rid] = area
	
	# Apply impulse to knock objects away based on damage over distance
	for rid in collisions_unique.keys():
		var intersection : Dictionary = collisions_unique[rid]
		var distance = global_position.distance_to(intersection.position) 
		var scaled_damage = owner.bomb_damage / (1 + distance)
		if intersection.collider is RigidBody3D:
			var body = intersection.collider as RigidBody3D
			body.apply_impulse(
				intersection.position - body.global_position,
				global_position.direction_to(intersection.position)*scaled_damage * IMPULSE_MULTIPLIER
			)
					
		# If the body has a hitbox, apply damage
		elif intersection.collider is Hitbox:
			print("Bomb area intersected with Hitbox")
			var object = intersection.collider.owner
			if is_instance_valid(object) and object.has_method("damage"):
				object.damage(floor(scaled_damage), owner.damage_type, intersection.collider)
				print("Bomb exploded and detected a character, ",object, " with damage() method for ", scaled_damage)
