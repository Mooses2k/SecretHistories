extends GutTest

# Doors lane regression (owner live playtest blocker): the player interact
# controller only ever sees the Interactable Area3D, never the door behind
# it, so its `interact_target.has_method(&"interact_hold_update")` gate read
# false live and HOLD_INTERACT was never entered: the door began a hold
# follow it was never fed, and sat shut. The relay on Interactable is the
# contract the controller drives; these tests pin it from the controller's
# point of view.

const DOOR_SCENE := preload("res://scenes/objects/large_objects/doors/base_kinematic_door.tscn")

var door : BaseKinematicDoor


class RelayRecorder:
	extends Node

	var updates : Array = []
	var ended : int = 0

	func interact_hold_update(origin : Vector3, dir : Vector3):
		updates.append([origin, dir])

	func interact_hold_end():
		ended += 1


func before_each():
	door = DOOR_SCENE.instantiate()
	add_child_autofree(door)
	door.process_mode = Node.PROCESS_MODE_DISABLED


func test_controller_gate_accepts_a_hold_interact_interactable():
	# The exact check interact_controller._process runs past the hold
	# threshold before entering HOLD_INTERACT.
	assert_true(door.interactable_area.hold_interact, "door opts into hold interact")
	assert_true(door.interactable_area.has_method(&"interact_hold_update"),
			"controller gate passes for the door's Interactable")
	assert_true(door.interactable_area.has_method(&"interact_hold_end"),
			"release gate passes for the door's Interactable")


func test_door_registers_itself_as_hold_follow_owner():
	assert_eq(door.interactable_area.hold_follow_owner, door,
			"door _ready registers itself as the relay owner")


func test_relay_forwards_hold_update_to_the_owner():
	var recorder := RelayRecorder.new()
	autofree(recorder)
	door.interactable_area.hold_follow_owner = recorder
	var origin := Vector3(1.0, 2.0, 3.0)
	var dir := Vector3(0.0, -1.0, 0.0)
	door.interactable_area.interact_hold_update(origin, dir)
	assert_eq(recorder.updates.size(), 1)
	assert_eq(recorder.updates[0][0], origin)
	assert_eq(recorder.updates[0][1], dir)


func test_relay_forwards_hold_end_to_the_owner():
	var recorder := RelayRecorder.new()
	autofree(recorder)
	door.interactable_area.hold_follow_owner = recorder
	door.interactable_area.interact_hold_end()
	assert_eq(recorder.ended, 1)


func test_relay_is_silent_without_an_owner():
	# Targets that only react to tap or hold, no follow: must not crash
	door.interactable_area.hold_follow_owner = null
	door.interactable_area.interact_hold_update(Vector3.ZERO, Vector3.UP)
	door.interactable_area.interact_hold_end()
	assert_true(true, "no owner set: relay is a no-op")


func test_relay_tolerates_a_freed_owner():
	var recorder := RelayRecorder.new()
	door.interactable_area.hold_follow_owner = recorder
	recorder.free()
	door.interactable_area.interact_hold_update(Vector3.ZERO, Vector3.UP)
	door.interactable_area.interact_hold_end()
	assert_true(true, "freed owner: relay is a no-op")


func test_relay_end_to_end_drives_the_real_door():
	# The live contract in order: controller fires interact on a hold, then
	# feeds the relay every physics frame, then calls relay end on release.
	door.interactable_area.interact_press_was_hold = true
	door._on_Interactable_character_interacted(null)
	assert_eq(door.follow_mode, BaseKinematicDoor.FollowMode.HOLD_FOLLOW)
	# A hand ray onto the swing plane at full open
	var hinge : Node3D = door.door_hinge_z_axis
	var plane_y := hinge.global_position.y + BaseKinematicDoor.HOLD_PLANE_HEIGHT
	var hand : Vector3 = hinge.global_position \
			+ (Basis(Vector3.UP, door.door_open_angle) * Vector3(-1.0, 0.0, 0.0))
	door.interactable_area.interact_hold_update(
			Vector3(hand.x, plane_y + 2.0, hand.z), Vector3(0.0, -1.0, 0.0))
	door._physics_process(1.0 / 60.0)
	assert_gt(door.door_hinge_z_axis.rotation.y, 0.0, "relayed drag moves the hinge")
	door.interactable_area.interact_hold_end()
	assert_eq(door.follow_mode, BaseKinematicDoor.FollowMode.FREE, "relayed release coasts")
