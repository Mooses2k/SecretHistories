extends GutTest

## Issue #743: the thrown hatchet's whoosh loop must stop when the hatchet
## stops spinning, even when the first-contact stop has nothing to act on
## (thrower-only or collider-less contacts), and it must not outlive the
## DROPPED state. Each test drives one real weapon scene through live physics
## ticks in an empty volume so no contact path can fire and only the spin
## rules decide the loop's fate.

const HATCHET_SCENE := preload("res://scenes/objects/pickable_items/equipment/melee/hatchet/hatchet.tscn")
const MACE_SCENE := preload("res://scenes/objects/pickable_items/equipment/melee/mace/mace.tscn")


func _spawn(scene : PackedScene) -> MeleeItem:
	# One weapon per test: two free bodies in one volume collide with each
	# other, and that first contact legitimately stops the loop.
	var weapon : MeleeItem = scene.instantiate()
	add_child_autofree(weapon)
	# The live throw path stamps the thrower before the loop starts; with no
	# real thrower here, self stands in so the contact rule never reads a
	# missing meta key.
	weapon.set_meta("thrown_by", weapon)
	return weapon


func _throw(weapon : MeleeItem) -> void:
	# Same order the live throw path uses: state first, spin second, loop last.
	weapon.set_item_state(GlobalConsts.ItemState.DROPPED)
	weapon.apply_throw_logic(Vector3.UP)
	weapon.play_throw_sound()


func _spin_for(frames : int) -> void:
	for i in frames:
		await get_tree().physics_frame


func test_stalled_spin_stops_the_loop_without_any_contact():
	var hatchet := _spawn(HATCHET_SCENE)
	_throw(hatchet)
	assert_true(hatchet.audio_player.playing, "throw starts the whoosh loop")
	await _spin_for(12)
	assert_true(hatchet.audio_player.playing, "a spinning hatchet keeps whooshing")
	hatchet.angular_velocity = Vector3.ZERO
	await _spin_for(3)
	assert_false(hatchet.audio_player.playing, "a stalled spin stops the whoosh loop")


func test_the_same_stall_rule_covers_other_spin_throwing_melee_weapons():
	var mace := _spawn(MACE_SCENE)
	_throw(mace)
	await _spin_for(12)
	assert_true(mace.audio_player.playing, "a spinning mace keeps whooshing")
	mace.angular_velocity = Vector3.ZERO
	await _spin_for(3)
	assert_false(mace.audio_player.playing, "a stalled mace spin stops the loop")


func test_leaving_dropped_stops_a_still_playing_loop():
	var hatchet := _spawn(HATCHET_SCENE)
	_throw(hatchet)
	assert_true(hatchet.audio_player.playing)
	hatchet.set_item_state(GlobalConsts.ItemState.EQUIPPED)
	assert_false(hatchet.audio_player.playing, "pickup stops the whoosh loop")


func test_a_wall_hit_stops_the_loop_through_the_contact_rule():
	# The issue's surface-hit case: the thrown hatchet connects with a wall
	# and the whoosh must die there, through the existing first-contact rule.
	var hatchet := _spawn(HATCHET_SCENE)
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 2.0, 0.1)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	add_child_autofree(wall)
	wall.global_position = hatchet.global_position + Vector3(0.0, 0.0, -1.0)
	_throw(hatchet)
	hatchet.linear_velocity = Vector3(0.0, 0.0, -10.0)
	assert_true(hatchet.audio_player.playing, "the throw whooshes toward the wall")
	await _spin_for(25)
	assert_false(hatchet.audio_player.playing, "a wall hit stops the whoosh loop")
	assert_lt(hatchet.linear_velocity.length(), 5.0,
			"the hatchet really reached the wall before the assert ran")


func test_a_spin_that_never_went_active_is_left_to_the_contact_stop():
	# The stall rule latches only after the spin reached active speed, so a
	# loop whose carrier never spins is never cut by the stall rule.
	var hatchet := _spawn(HATCHET_SCENE)
	_throw(hatchet)
	hatchet.angular_velocity = Vector3.ZERO
	await _spin_for(6)
	assert_true(hatchet.audio_player.playing,
			"no active spin latch means the stall rule stays hands off")
