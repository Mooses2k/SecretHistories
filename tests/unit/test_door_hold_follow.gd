extends GutTest

# Doors lane: Amnesia-style hold-follow interaction logic (owner rulings,
# November 2026). Logic level: the real door scene with processing disabled,
# physics steps driven manually so assertions are deterministic.

const DOOR_SCENE := preload("res://scenes/objects/large_objects/doors/base_kinematic_door.tscn")

var door : BaseKinematicDoor


func before_each():
	door = DOOR_SCENE.instantiate()
	add_child_autofree(door)
	# Deterministic stepping: no automatic processing, manual _physics_process
	door.process_mode = Node.PROCESS_MODE_DISABLED
	door.door_stuck_on_close_probability = 0.0


func _step(times : int, delta := 1.0 / 60.0):
	for i in times:
		door._physics_process(delta)


## Hand point for a given hinge target angle, plus a straight-down ray onto
## the swing plane so interact_hold_update resolves it.
func _drag_ray(target_angle : float) -> Array:
	var hinge : Node3D = door.door_hinge_z_axis
	var hand : Vector3 = hinge.global_position + (Basis(Vector3.UP, target_angle) * Vector3(-1.0, 0.0, 0.0))
	var plane_y := hinge.global_position.y + BaseKinematicDoor.HOLD_PLANE_HEIGHT
	var origin := Vector3(hand.x, plane_y + 2.0, hand.z)
	return [origin, Vector3(0.0, -1.0, 0.0)]


func test_tap_does_nothing_on_normal_closed_door():
	door.interactable_area.interact_press_was_hold = false
	door._on_Interactable_character_interacted(null)
	assert_eq(door.door_state, BaseKinematicDoor.DoorState.CLOSED)
	assert_almost_eq(door.door_hinge_z_axis.rotation.y, 0.0, 0.0001)
	assert_eq(door.follow_mode, BaseKinematicDoor.FollowMode.FREE)


func test_hold_begins_follow_and_marks_open():
	door.interactable_area.interact_press_was_hold = true
	door._on_Interactable_character_interacted(null)
	assert_eq(door.follow_mode, BaseKinematicDoor.FollowMode.HOLD_FOLLOW)
	assert_eq(door.door_state, BaseKinematicDoor.DoorState.OPEN)


func test_follow_tracks_hand_with_lag_not_teleport():
	door.interactable_area.interact_press_was_hold = true
	door._on_Interactable_character_interacted(null)
	# Hand target: full open (drag past the open end clamps to door_open_angle)
	var ray := _drag_ray(door.door_open_angle)
	door.interact_hold_update(ray[0], ray[1])
	# One step: the hinge must have moved toward the target but NOT arrived
	door._physics_process(1.0 / 60.0)
	var angle_after_one : float = door.door_hinge_z_axis.rotation.y
	assert_gt(angle_after_one, 0.0, "follow starts moving the hinge")
	assert_lt(angle_after_one, door.door_open_angle, "follow lags, no teleport")
	# Many steps converge on the target
	_step(240)
	assert_almost_eq(door.door_hinge_z_axis.rotation.y, door.door_open_angle, 0.02)


func test_hold_update_reaches_into_room_side_target():
	door.interactable_area.interact_press_was_hold = true
	door._on_Interactable_character_interacted(null)
	# A hand point on the closed side: the target clamps to 0 and the door
	# stays shut (the leaf never sweeps to the corridor side)
	var ray := _drag_ray(0.0)
	door.interact_hold_update(ray[0], ray[1])
	_step(120)
	assert_almost_eq(door.door_hinge_z_axis.rotation.y, 0.0, 0.02)


func test_release_carries_momentum_into_coast():
	door.interactable_area.interact_press_was_hold = true
	door._on_Interactable_character_interacted(null)
	var ray := _drag_ray(door.door_open_angle)
	door.interact_hold_update(ray[0], ray[1])
	_step(30)
	door.interact_hold_end()
	assert_eq(door.follow_mode, BaseKinematicDoor.FollowMode.FREE)
	assert_gt(door._angular_velocity, 0.0, "release carries angular momentum")
	_step(1)
	# The coast integrates the carried velocity, not a scripted timer
	assert_gt(door.door_hinge_z_axis.rotation.y, 0.0)


func test_stationary_release_stays_put():
	door.interactable_area.interact_press_was_hold = true
	door._on_Interactable_character_interacted(null)
	# No drag updates: the follow never built speed; omega stays tiny
	_step(10)
	door.interact_hold_end()
	assert_eq(door._angular_velocity, 0.0, "nearly stationary release is arrested")
	var rest_angle : float = door.door_hinge_z_axis.rotation.y
	_step(60)
	assert_almost_eq(door.door_hinge_z_axis.rotation.y, rest_angle, 0.0001)


func test_latch_absorbs_slow_close_and_settles_shut():
	door.door_hinge_z_axis.rotation.y = 0.05
	door.follow_mode = BaseKinematicDoor.FollowMode.FREE
	door._angular_velocity = -BaseKinematicDoor.LATCH_ABSORB_SPEED * 0.5
	_step(30)
	assert_almost_eq(door.door_hinge_z_axis.rotation.y, 0.0, 0.0001)
	assert_eq(door.door_state, BaseKinematicDoor.DoorState.CLOSED)
	assert_eq(door._angular_velocity, 0.0)


func test_latch_bounces_hard_close_back_open():
	door.door_hinge_z_axis.rotation.y = 0.05
	door.follow_mode = BaseKinematicDoor.FollowMode.FREE
	door._angular_velocity = -BaseKinematicDoor.LATCH_ABSORB_SPEED * 3.0
	# The closing coast carries the door into the frame at high momentum
	var bounced := false
	for i in 120:
		door._physics_process(1.0 / 60.0)
		if door.door_hinge_z_axis.rotation.y <= 0.0:
			# Latch contact: fast momentum must flip the velocity back open
			bounced = door._angular_velocity > 0.0
			break
	assert_true(bounced, "hard close bounces back open")
	assert_ne(door.door_state, BaseKinematicDoor.DoorState.CLOSED, "bounced door is not closed")
	# The bounce coasts open, then settles
	_step(300)
	assert_gt(door.door_hinge_z_axis.rotation.y, 0.0, "bounce leaves the door ajar")


func test_room_side_score_orders_room_over_hall_over_other():
	var data := WorldData.new()
	data.resize(3, 3)
	var room_cell := data.get_cell_index_from_int_position(1, 1)
	data.set_cell_type(room_cell, data.CellType.ROOM)
	var hall_cell := data.get_cell_index_from_int_position(0, 0)
	data.set_cell_type(hall_cell, data.CellType.HALL)
	var empty_cell := data.get_cell_index_from_int_position(2, 2)
	assert_eq(BaseKinematicDoor.room_side_score(data, room_cell), 2)
	assert_eq(BaseKinematicDoor.room_side_score(data, hall_cell), 1)
	assert_eq(BaseKinematicDoor.room_side_score(data, empty_cell), 0)


func test_locked_door_hold_does_not_swing():
	door.is_locked = true
	door.interactable_area.interact_press_was_hold = true
	door._on_Interactable_character_interacted(null)
	# Locked branch reacts (rattle) and never grabs the leaf
	assert_eq(door.follow_mode, BaseKinematicDoor.FollowMode.FREE)
	assert_eq(door.door_state, BaseKinematicDoor.DoorState.CLOSED)


func test_stuck_door_hold_does_not_swing():
	door.door_state = BaseKinematicDoor.DoorState.STUCK
	door.interactable_area.interact_press_was_hold = true
	door._on_Interactable_character_interacted(null)
	assert_eq(door.follow_mode, BaseKinematicDoor.FollowMode.FREE)
	assert_eq(door.door_state, BaseKinematicDoor.DoorState.STUCK)
