extends GutTest

# Doors lane: body-contact push (owner ruling: a door has real mass against
# the player's body). Physics level: the real door scene with live physics,
# a rigid body playing the pusher's role, velocity re-applied every physics
# frame like a walking character leaning into the leaf.

const DOOR_SCENE := preload("res://scenes/objects/large_objects/doors/base_kinematic_door.tscn")

var door : BaseKinematicDoor


func before_each():
	door = DOOR_SCENE.instantiate()
	add_child_autofree(door)
	door.door_stuck_on_close_probability = 0.0


func _make_pusher(press_speed : float, from_front : bool) -> RigidBody3D:
	# A rigid body slab hovering beside the leaf face, pressing into it.
	# from_front = the -Z face side (pushing swings the door open);
	# otherwise the +Z face side (pushing drives it shut).
	var body := RigidBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 0.4, 0.4)
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	var leaf : Node3D = door.door_body
	var side := -1.0 if from_front else 1.0
	body.global_position = leaf.global_position + leaf.global_basis.z * (0.4 * side) + Vector3(0.0, 0.3, 0.0)
	body.set_meta(&"face", side)
	body.set_meta(&"press", press_speed)
	return body


func _press_for(body : RigidBody3D, steps : int):
	# Like a real arm pressing the leaf: stay on the press face and push
	# into it every physics frame (the closing kinematic leaf sweeps past a
	# free rigid box, which no real pusher does)
	var side : float = body.get_meta(&"face")
	var press : float = body.get_meta(&"press")
	for i in steps:
		await get_tree().physics_frame
		var leaf : Node3D = door.door_body
		body.global_position = leaf.global_position + leaf.global_basis.z * (0.3 * side) + Vector3(0.0, 0.3, 0.0)
		body.linear_velocity = leaf.global_basis.z * (press * -side)


func _angle() -> float:
	return door.door_hinge_z_axis.rotation.y


func test_shoulder_push_unlatches_and_opens_a_shut_door():
	var pusher := _make_pusher(3.0, true)
	await _press_for(pusher, 90)
	assert_gt(_angle(), 0.3, "a walking push opens the shut door")
	assert_eq(door.follow_mode, BaseKinematicDoor.FollowMode.FREE, "body push uses the free momentum model")


func test_sustained_push_accelerates_toward_the_cap():
	# Owner feedback: continuing to push must ACCELERATE the door, not hold
	# one constant speed. Sustained contact grows the press memory, so the
	# chased angular velocity ramps up to PUSH_MAX_SPEED.
	var pusher := _make_pusher(3.0, true)
	var early_speed : float = 0.0
	var late_speed : float = 0.0
	for i in range(96):
		await get_tree().physics_frame
		pusher.global_position = door.door_body.global_position \
				+ door.door_body.global_basis.z * (-0.3) + Vector3(0.0, 0.3, 0.0)
		pusher.linear_velocity = door.door_body.global_basis.z * 3.0
		if i == 18:
			early_speed = absf(door._angular_velocity)
		if i == 78:
			late_speed = absf(door._angular_velocity)
	assert_gt(late_speed, early_speed * 2.0,
			"sustained push accelerates the swing (late %.2f vs early %.2f)" % [late_speed, early_speed])
	assert_gt(late_speed, 1.5, "hard sustained push approaches the terminal cap")


func test_light_brush_is_absorbed_by_the_latch():
	var pusher := _make_pusher(0.25, true)
	await _press_for(pusher, 40)
	assert_almost_eq(_angle(), 0.0, 0.001, "a light brush does not move a shut door")


func test_body_push_shuts_an_open_door():
	var pusher := _make_pusher(3.0, false)
	# Start mid-swing, open and resting
	door.door_hinge_z_axis.rotation.y = door.door_open_angle * 0.5
	door.door_state = 0  # OPEN
	await _press_for(pusher, 90)
	assert_lt(_angle(), door.door_open_angle * 0.5, "pressing the open leaf drives it shut")
