extends GutTest

# Doors lane: broken-door penetration sweep + oscillation watchdog unit tests.
# The scene is instantiated with processing disabled so piece physics and the
# settle timer never run on their own; every path under test is driven by a
# direct call so the assertions are deterministic.

const SCENE := preload("res://scenes/objects/large_objects/doors/base_broken_door.tscn")

var door : Node3D


func before_each():
	door = SCENE.instantiate()
	add_child_autofree(door)
	door.process_mode = Node.PROCESS_MODE_DISABLED


func _pieces() -> Array:
	var result := []
	for child in door.get_children():
		if child is RigidBody3D:
			result.append(child)
	return result


func test_embedded_piece_is_lifted_not_deleted_by_the_sweep():
	var piece : RigidBody3D = _pieces()[0]
	piece.global_position = Vector3(0.5, -0.03, 0.5)
	# The sweep skips ticks inside the grace period; processing is disabled
	# so _elapsed never advances on its own
	door._elapsed = 10.0
	door._on_SettleLiftTimer_timeout()
	assert_false(piece.is_queued_for_deletion(), "sweep never deletes")
	var bottom : float = door._piece_bottom_y(piece)
	assert_gt(bottom, 0.0 - 0.001, "embedded piece now rests on the floor surface")


func test_resting_piece_is_untouched_by_the_sweep():
	var piece : RigidBody3D = _pieces()[1]
	# Park it fully above the floor
	var bottom : float = door._piece_bottom_y(piece)
	piece.global_position.y += (0.05 - bottom)
	var pos_before : Vector3 = piece.global_position
	door._on_SettleLiftTimer_timeout()
	assert_eq(piece.global_position, pos_before, "a resting piece is not moved")


func test_watchdog_first_offense_freezes_and_lifts_out():
	var piece : RigidBody3D = _pieces()[2]
	piece.global_position = Vector3(0.5, -0.05, 0.5)
	var index := 2
	door._watchdog_trigger(index, piece)
	assert_false(piece.is_queued_for_deletion(), "first offense never deletes")
	assert_true(piece.freeze, "first offense freezes the piece")
	assert_eq(piece.linear_velocity, Vector3.ZERO)
	var bottom : float = door._piece_bottom_y(piece)
	assert_gt(bottom, 0.2, "lifted clear above the floor")


func test_watchdog_second_offense_deletes_the_piece():
	var piece : RigidBody3D = _pieces()[3]
	var index := 3
	door._watchdog_trigger(index, piece)
	door._watchdog_trigger(index, piece)
	assert_true(piece.is_queued_for_deletion(), "persistent oscillator is deleted")


func test_unliftable_piece_is_deleted_on_first_offense():
	var piece : RigidBody3D = _pieces()[4]
	# Strip its collision shapes: no measurable bottom, cannot be lifted.
	# free() (immediate) so the shapes are really gone when the trigger runs.
	for shape in piece.find_children("", "CollisionShape3D", true, false):
		shape.free()
	door._watchdog_trigger(4, piece)
	assert_true(piece.is_queued_for_deletion(), "unliftable oscillator does not stay")


func test_reversal_counting_fires_after_four_flips_in_band():
	var piece : RigidBody3D = _pieces()[5]
	piece.global_position = Vector3(0.5, -0.05, 0.5)
	var speed := 0.2
	var signs := [1.0, -1.0, 1.0, -1.0, 1.0]
	for s in signs:
		piece.linear_velocity = Vector3(speed * s, 0, 0)
		door._watchdog_step(5, piece)
	assert_true(piece.freeze, "four reversals in the band trigger the freeze+lift")
	assert_false(piece.is_queued_for_deletion(), "first offense lifts, not deletes")
	var bottom : float = door._piece_bottom_y(piece)
	assert_gt(bottom, 0.2, "lifted out of the floor after detection")


func test_energetic_piece_does_not_count_as_jitter():
	var piece : RigidBody3D = _pieces()[6]
	piece.global_position = Vector3(0.5, -0.05, 0.5)
	# A hard tumble reverses too but sits above the jitter band: not jitter
	for i in 10:
		piece.linear_velocity = Vector3(3.0 if i % 2 == 0 else -3.0, 0, 0)
		door._watchdog_step(6, piece)
	assert_false(piece.freeze, "energetic reversal is legitimate motion")
