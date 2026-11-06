# Tests for the damping capture/restore in interact_controller.gd (Brooks Wave 1
# row 5): the grab start captures the target's pre-grab linear_damp,
# angular_damp and gravity_scale, damping factors applied during the grab stay
# local (the exported factors are never assigned), and release restores exactly
# the captured values.
# The controller is driven manually: it is instantiated without entering the
# tree (its @onready scene paths do not exist here) and its grab start /
# physics / release entry points are called directly with a lightweight
# RigidBody3D target, a real RayCast3D stand-in for grab_cast, and a GUT double
# of PlayerController for the drag speed hand-off.
extends GutTest

const InteractControllerScript = preload("res://scenes/characters/player/interact_controller.gd")
const PlayerControllerScript = preload("res://scenes/characters/player/player_controller.gd")

const AUTHORED_LINEAR_DAMP := 0.7
const AUTHORED_ANGULAR_DAMP := 0.9
const AUTHORED_GRAVITY_SCALE := 0.5


func _make_controller() -> Node:
	var controller = InteractControllerScript.new()
	var player_controller = double(PlayerControllerScript).new()
	# set_drag_speed_modifier touches the real controller's unresolved @onready
	# input node off-tree, so the double no-ops it.
	stub(player_controller, "set_drag_speed_modifier").to_do_nothing()
	controller.player_controller = player_controller
	autofree(controller)
	autofree(player_controller)
	return controller


func _make_grab_cast() -> RayCast3D:
	var cast = RayCast3D.new()
	add_child_autofree(cast)
	return cast


func _make_target(mass : float) -> RigidBody3D:
	var target = RigidBody3D.new()
	target.mass = mass
	target.linear_damp = AUTHORED_LINEAR_DAMP
	target.angular_damp = AUTHORED_ANGULAR_DAMP
	target.gravity_scale = AUTHORED_GRAVITY_SCALE
	add_child_autofree(target)
	return target


func _grab(controller : Node, target : RigidBody3D) -> void:
	controller.captured_grab_target = target
	assert_true(controller._try_grab_captured(), "precondition: the grab succeeds")


func test_grab_start_captures_pre_grab_physics_values():
	var controller = _make_controller()
	controller.grab_cast = _make_grab_cast()
	var target = _make_target(2.0)

	_grab(controller, target)

	# Physics properties round-trip through 32-bit floats, so compare with tolerance.
	assert_almost_eq(controller.pre_grab_linear_damp, AUTHORED_LINEAR_DAMP, 0.001, "pre-grab linear damp captured")
	assert_almost_eq(controller.pre_grab_angular_damp, AUTHORED_ANGULAR_DAMP, 0.001, "pre-grab angular damp captured")
	assert_eq(controller.pre_grab_gravity_scale, AUTHORED_GRAVITY_SCALE, "pre-grab gravity scale captured")


func test_release_restores_exactly_the_captured_values():
	var controller = _make_controller()
	controller.grab_cast = _make_grab_cast()
	var target = _make_target(2.0)
	_grab(controller, target)

	# Simulate the in-grab state: physics damping has been applied to the body.
	target.linear_damp = 3.5
	target.angular_damp = 2.5
	target.gravity_scale = 0.2

	controller._reset_object_damping(controller.grabbed_item)

	assert_almost_eq(target.linear_damp, AUTHORED_LINEAR_DAMP, 0.001, "linear damp restored to the captured value")
	assert_almost_eq(target.angular_damp, AUTHORED_ANGULAR_DAMP, 0.001, "angular damp restored to the captured value")
	assert_eq(target.gravity_scale, AUTHORED_GRAVITY_SCALE, "gravity scale restored to the captured value")


func test_exported_damping_factors_are_never_assigned_by_a_grab_cycle():
	var controller = _make_controller()
	controller.grab_cast = _make_grab_cast()
	var target = _make_target(0.2)  # light mass: the 8.0 local override branch
	_grab(controller, target)

	# Two physics steps under the light-mass branch, which used to overwrite
	# the exported factors with the 8.0 override.
	controller._physics_process(0.016)
	controller._physics_process(0.016)
	assert_gt(target.linear_damp, AUTHORED_LINEAR_DAMP, "damping was applied to the body during the grab")

	# Release and immediately grab again: the second capture must read the
	# authored values, not a leftover from the local override path.
	controller._reset_object_damping(controller.grabbed_item)
	assert_almost_eq(target.linear_damp, AUTHORED_LINEAR_DAMP, 0.001, "release restores the authored damp after a light-object grab")

	var target_two = _make_target(2.0)
	_grab(controller, target_two)
	assert_almost_eq(controller.pre_grab_linear_damp, AUTHORED_LINEAR_DAMP, 0.001, "second capture reads authored linear damp")
	assert_almost_eq(controller.pre_grab_angular_damp, AUTHORED_ANGULAR_DAMP, 0.001, "second capture reads authored angular damp")
	assert_eq(controller.pre_grab_gravity_scale, AUTHORED_GRAVITY_SCALE, "second capture reads authored gravity scale")

	assert_eq(controller.linear_damping_factor, 4.0, "exported linear damping factor is unchanged after the cycle")
	assert_eq(controller.rotational_damping_factor, 2.0, "exported rotational damping factor is unchanged after the cycle")
	assert_eq(controller.mass_damping_scale, 1.0, "exported mass damping scale is unchanged after the cycle")
