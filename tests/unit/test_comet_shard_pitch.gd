extends GutTest

## The comet shard's chant pitch scaler (3.x behavior, clamped):
## the chant deepens as the player closes in and relaxes back toward
## natural pitch at distance; inside 1 m it clamps instead of going negative.

const SHARD_SCENE := "res://scenes/objects/pickable_items/equipment/strange_devices/comet_shard/comet_shard.tscn"


func _shard() -> Node:
	return load(SHARD_SCENE).instantiate()


func test_pitch_relaxes_toward_natural_at_distance():
	var shard = _shard()
	add_child_autofree(shard)
	assert_almost_eq(shard._pitch_for_distance(100.0), 0.99, 0.001,
		"far away the chant is nearly natural pitch")
	assert_almost_eq(shard._pitch_for_distance(10.0), 0.9, 0.001,
		"mid-distance deepening per the 3.x curve")


func test_pitch_deepens_as_the_player_closes_in():
	var shard = _shard()
	add_child_autofree(shard)
	assert_almost_eq(shard._pitch_for_distance(2.0), 0.5, 0.001,
		"2 m away the chant is half speed")


func test_pitch_clamps_inside_one_meter_instead_of_going_negative():
	var shard = _shard()
	add_child_autofree(shard)
	assert_almost_eq(shard._pitch_for_distance(1.0), 0.01, 0.0001,
		"at 1 m the curve hits zero and clamps to the deepest valid pitch")
	assert_almost_eq(shard._pitch_for_distance(0.5), 0.01, 0.0001,
		"inside the killzone the clamp holds, no negative pitch_scale")
	assert_gt(shard._pitch_for_distance(0.5), 0.0,
		"pitch_scale stays a valid positive value near the shard")


func test_chant_updates_without_a_valid_game_reference_without_error():
	var shard = _shard()
	add_child_autofree(shard)
	shard._pitch_alter_chant_based_on_distance()
	assert_true(true, "the instance-valid guard runs clean with no game set")
