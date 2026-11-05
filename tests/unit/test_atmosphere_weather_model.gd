# Tests for the two-level atmosphere weather model in generate_atmosphere_group.gd.
# Owner model: per floor one roll picks normal (0.85) / special all-fog (0.10) /
# special all-dust (0.05); normal floors then pick the family type (fog 0.8) and
# roll per-room presence (fog 0.25 / dust 0.08). A fixed seed must be
# deterministic. Roll logic is embedded in _execute_step, so the test observes
# it through observer children on an empty real WorldData (no fake WorldData).
extends GutTest

const AtmosScript = preload("res://scenes/worlds/world_gen/generation_steps/populate_room/generate_atmosphere_group.gd")
const ObserverScript = preload("res://tests/unit/weather_observer_step.gd")

const FOG_VARIANTS := ["FOG_A", "FOG_B", "FOG_C"]
const DUST_VARIANTS := ["DUST_A", "DUST_B", "DUST_C"]

const TEST_SEED := 12345


func before_each():
	# The step mixes the floor level into the seed via GameManager when a game
	# exists; force the headless fallback path for a fixed-seed prediction.
	GameManager.game = null


func _make_run(seed : int) -> Array:
	var group = AtmosScript.new()
	group.fog_half_height_scene_path = FOG_VARIANTS[0]
	group.fog_swirl_scene_path = FOG_VARIANTS[1]
	group.fog_thick_scene_path = FOG_VARIANTS[2]
	group.dust_scene_path = DUST_VARIANTS[0]
	group.flecks_scene_path = DUST_VARIANTS[1]
	group.plague_scene_path = DUST_VARIANTS[2]
	var fog_observer = ObserverScript.new()
	fog_observer.accepts_fog_weather = true
	var dust_observer = ObserverScript.new()
	dust_observer.accepts_fog_weather = false
	group.add_child(fog_observer)
	group.add_child(dust_observer)
	add_child_autofree(group)
	group._execute_step(WorldData.new(), {}, seed)
	return [fog_observer, dust_observer]


## Replicates the documented roll order to predict the branch for a seed.
func _predict(seed : int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var floor_roll := rng.randf()
	if floor_roll < 0.85:
		var is_fog_type := rng.randf() < 0.8
		# No rooms in the empty WorldData, so no per-room rolls and no variant.
		return {
			"fog_path": "",
			"dust_path": "",
			"family": "fog_type" if is_fog_type else "dust_type",
		}
	if floor_roll < 0.85 + 0.10:
		return {
			"fog_path": FOG_VARIANTS[rng.randi() % 3],
			"dust_path": "",
			"family": "special_all_fog",
		}
	return {
		"fog_path": "",
		"dust_path": DUST_VARIANTS[rng.randi() % 3],
		"family": "special_all_dust",
	}


func test_owner_confirmed_chances_are_the_defaults():
	var group = AtmosScript.new()
	assert_eq(group.normal_floor_chance, 0.85, "normal floor chance")
	assert_eq(group.special_fog_floor_chance, 0.10, "special all-fog floor chance")
	assert_eq(group.special_dust_floor_chance, 0.05, "special all-dust floor chance")
	assert_eq(group.fog_type_chance, 0.8, "fog dominates the family type roll")
	assert_eq(group.fog_room_chance, 0.25, "fog room presence chance")
	assert_eq(group.dust_room_chance, 0.08, "dust room presence chance")
	group.free()


func test_fixed_seed_produces_deterministic_outcome():
	var first := _make_run(TEST_SEED)
	var second := _make_run(TEST_SEED)
	assert_eq(first[0].captured_weather_scene_path, second[0].captured_weather_scene_path, "fog routing is seed-deterministic")
	assert_eq(first[1].captured_weather_scene_path, second[1].captured_weather_scene_path, "dust routing is seed-deterministic")
	assert_eq(first[0].captured_room_paths, second[0].captured_room_paths, "fog room paths are seed-deterministic")
	assert_eq(first[1].captured_room_paths, second[1].captured_room_paths, "dust room paths are seed-deterministic")


func test_roll_branch_matches_owner_model_for_fixed_seed():
	var prediction := _predict(TEST_SEED)
	var run := _make_run(TEST_SEED)
	var fog_observer = run[0]
	var dust_observer = run[1]
	assert_eq(fog_observer.captured_weather_scene_path, prediction.fog_path, "fog family got the predicted floor-wide scene")
	assert_eq(dust_observer.captured_weather_scene_path, prediction.dust_path, "dust family got the predicted floor-wide scene")
	assert_true(
		fog_observer.captured_weather_scene_path == "" or dust_observer.captured_weather_scene_path == "",
		"fog and dust never coexist on one floor")
	if prediction.family != "special_all_fog" and prediction.family != "special_all_dust":
		# Normal floor with an empty room set: nothing is routed, room paths empty.
		assert_eq(fog_observer.captured_room_paths, {}, "no fog room paths on an empty normal floor")
		assert_eq(dust_observer.captured_room_paths, {}, "no dust room paths on an empty normal floor")
	else:
		assert_eq(fog_observer.captured_room_paths, {}, "special floors route floor-wide, not per room")


func test_fog_and_dust_variants_map_randi_remainder_to_the_three_paths():
	var group = AtmosScript.new()
	group.fog_half_height_scene_path = FOG_VARIANTS[0]
	group.fog_swirl_scene_path = FOG_VARIANTS[1]
	group.fog_thick_scene_path = FOG_VARIANTS[2]
	group.dust_scene_path = DUST_VARIANTS[0]
	group.flecks_scene_path = DUST_VARIANTS[1]
	group.plague_scene_path = DUST_VARIANTS[2]
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	# Seed the step's own rng so the variant picks match the prediction.
	group._rng.seed = TEST_SEED
	var fog_index := rng.randi() % 3
	var dust_index := rng.randi() % 3
	assert_eq(group._pick_fog_variant(), FOG_VARIANTS[fog_index], "fog variant follows _rng randi % 3")
	assert_eq(group._pick_dust_variant(), DUST_VARIANTS[dust_index], "dust variant follows _rng randi % 3")
	group.free()
