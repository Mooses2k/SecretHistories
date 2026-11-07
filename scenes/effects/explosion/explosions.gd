extends GPUParticles3D


const IMPULSE_MULTIPLIER = 1.0

var trigger = false

@onready var blastradius = %BlastRadius
@onready var timer = $Timer

func _on_Bomb_explosion():
	timer.start()
	var collisions = blastradius.get_overlapping_bodies()
	collisions.append_array(blastradius.get_overlapping_areas())

	# Prune duplicate collisions with the same body or area
	var collisions_unique : Dictionary = Dictionary()
	var space = get_world_3d().direct_space_state
	for collision in collisions:
		var raycast_params := PhysicsRayQueryParameters3D.new()
		raycast_params.from = global_position
		raycast_params.to = collision.global_position
		# The candidate's own character body parts must not shield its
		# hurtboxes: the exclusion set carries the bomb owner plus every
		# physics body owned by the candidate's character (the root body with
		# its cylinder and the ragdoll bones), so the rays pass through that
		# character and reach its hurtboxes directly. Level geometry and other
		# characters still block, and hit_from_inside stays false so shapes
		# containing the blast origin are skipped.
		raycast_params.exclude = _ray_exclusions(collision)
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
				global_position.direction_to(intersection.position) * scaled_damage * IMPULSE_MULTIPLIER
			)
			# Large rigid bodies (statues) take the same bomb damage
			# characters take: owner.bomb_damage with the /(1 + distance)
			# falloff, floored like the Hurtbox call below. A close grenade
			# (bomb_damage 150) breaks a breakable statue in one blast; a
			# distant one does not. Statics and unbreakable bodies no-op.
			LargeObjectShared.accumulate_bludgeoning_damage(body, floor(scaled_damage))

		# If the body has a Hurtbox, apply damage
		elif intersection.collider is Hurtbox:
			#print("Bomb area intersected with Hurtbox")
			#var object = intersection.collider.owner
			#if is_instance_valid(object) and object.has_method("damage"):
			(intersection.collider as Hurtbox).damage(floor(scaled_damage), owner.damage_type, intersection.position - global_position, global_position)
				#print("Bomb exploded and detected a character, ",object, " with damage() method for ", scaled_damage)


func _on_timer_timeout():
	owner.queue_free()


## RID exclusion list for the rays aimed at one candidate: the bomb owner
## plus every physics body owned by the candidate's own character (the root
## body with its cylinder and the ragdoll bones). Candidates without a
## character, like world geometry and loose props, only exclude the bomb
## owner.
func _ray_exclusions(candidate : Node3D) -> Array[RID]:
	var exclusions : Array[RID] = [owner.get_rid()]
	var character := _candidate_character(candidate)
	if character != null:
		exclusions.append(character.get_rid())
		for bone in character.find_children("*", "PhysicalBone3D", true, false):
			exclusions.append((bone as PhysicsBody3D).get_rid())
	return exclusions


## The character a candidate belongs to, or null. Hurtboxes map through their
## scene owner (Hurtbox.owner_node); bodies map through the ancestor chain.
func _candidate_character(candidate : Node3D) -> HumanoidCharacter:
	var node : Node = candidate
	if node is Hurtbox:
		node = (node as Hurtbox).owner_node
	while node != null:
		if node is HumanoidCharacter:
			return node as HumanoidCharacter
		node = node.get_parent()
	return null
