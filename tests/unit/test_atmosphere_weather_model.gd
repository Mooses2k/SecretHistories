# Tests for the two-level atmosphere weather model in generate_atmosphere_group.gd.
# Owner model: per floor one roll picks normal (0.85) / special all-fog (0.10) /
# special all-dust (0.05); normal floors then pick the family type (fog 0.8).
# Fog rework owner ruling: fog PRESENCE is keyed to the ROOM TYPE via
# RoomPurpose.fog_rule + per-purpose fog_chance (copied onto RoomData), no
# longer a uniform per-room sprinkle: the OFTEN rooms carry their own chance
# as data (fountain 0.95, statue gallery 0.5 per the "Statue 50% fog"
# amendment), SOMETIMES rooms use the 0.08 fallback, NEVER rooms never. When
# a room IS fogged its VARIANT is a weighted pick: low 0.6 / medium 0.3 /
# full 0.1. Dust presence stays uniform (0.08). A fixed seed must be
# deterministic. Roll logic is embedded in _execute_step, so the test
# observes it through observer children and, for presence/variant stats,
# through room_paths on a populated WorldData.
extends GutTest

const AtmosScript = preload("res://scenes/worlds/world_gen/generation_steps/populate_room/generate_atmosphere_group.gd")
const ObserverScript = preload("res://tests/unit/weather_observer_step.gd")

const FOG_VARIANTS := ["FOG_A", "FOG_B", "FOG_C"]
const DUST_VARIANTS := ["DUST_A", "DUST_B", "DUST_C"]

const TEST_SEED := 12345

# Stat-test room fleet and tolerance bands. Exact rates are seeded and will
# drift by seed choice, so assert inside generous bands around the chances.
const STAT_SEEDS := 400
const FOUNTAIN_ROOMS := 10 # chance 0.95
const STATUE_ROOMS := 10 # chance 0.5 (owner amendment)
const SOMETIMES_ROOMS := 40 # fallback 0.08
const NEVER_ROOMS := 5


func before_each():
	# The step mixes the floor level into the seed via GameManager when a game
	# exists; force the headless fallback path for a fixed-seed prediction.
	GameManager.game = null


func _make_run(seed : int, data : WorldData = null) -> Array:
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
	group._execute_step(data if data != null else WorldData.new(), {}, seed)
	return [fog_observer, dust_observer]


## Replicates the documented roll order to predict the branch for a seed.
## Level 1 uses the first two randf draws (floor character, family type).
func _predict(seed : int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var floor_roll := rng.randf()
	if floor_roll < 0.85:
		return {"family": "fog_type" if rng.randf() < 0.8 else "dust_type"}
	if floor_roll < 0.85 + 0.10:
		return {"family": "special_all_fog"}
	return {"family": "special_all_dust"}


func _stat_data() -> WorldData:
	var data := WorldData.new()
	data.resize(80, 44)
	for index in FOUNTAIN_ROOMS:
		data.fill_room_data(Rect2(2 + index * 6, 2, 3, 3), RoomData.OriginalPurpose.FOUNTAIN)
	for index in STATUE_ROOMS:
		data.fill_room_data(Rect2(2 + index * 6, 8, 3, 3), RoomData.OriginalPurpose.STATUE_GALLERY)
	for index in SOMETIMES_ROOMS:
		data.fill_room_data(
			Rect2(2 + (index % 12) * 6, 14 + (index / 12) * 4, 3, 3),
			RoomData.OriginalPurpose.CRYPT)
	for index in NEVER_ROOMS:
		data.fill_room_data(Rect2(2 + index * 6, 32, 3, 3), RoomData.OriginalPurpose.TROPHY_ROOM)
	# Assign the rules and per-purpose chances the way generate_room_purposes
	# would: the shipped chances on the often fleets, the small fallback on
	# crypts, NEVER (chance irrelevant) on trophy rooms.
	for room in data.get_all_rooms():
		match room.type:
			RoomData.OriginalPurpose.FOUNTAIN:
				room.fog_rule = RoomPurpose.FogRule.OFTEN
				room.fog_chance = 0.95
			RoomData.OriginalPurpose.STATUE_GALLERY:
				room.fog_rule = RoomPurpose.FogRule.OFTEN
				room.fog_chance = 0.5
			RoomData.OriginalPurpose.TROPHY_ROOM:
				room.fog_rule = RoomPurpose.FogRule.NEVER
	return data


func _variant_counts(paths : Dictionary) -> Array:
	var counts := [0, 0, 0]
	for path in paths.values():
		counts[FOG_VARIANTS.find(path)] += 1
	return counts


func test_owner_confirmed_chances_are_the_defaults():
	var group = AtmosScript.new()
	assert_eq(group.normal_floor_chance, 0.85, "normal floor chance")
	assert_eq(group.special_fog_floor_chance, 0.10, "special all-fog floor chance")
	assert_eq(group.special_dust_floor_chance, 0.05, "special all-dust floor chance")
	assert_eq(group.fog_type_chance, 0.8, "fog dominates the family type roll")
	assert_eq(group.FOG_WEIGHT_LOW, 0.6, "fog variant weight: low")
	assert_eq(group.FOG_WEIGHT_MEDIUM, 0.3, "fog variant weight: medium")
	assert_eq(group.FOG_WEIGHT_FULL, 0.1, "fog variant weight: full")
	assert_eq(group.dust_room_chance, 0.08, "dust room presence chance")
	group.free()
	# Fog presence chance is per-purpose data (owner "Statue 50% fog"); the
	# SOMETIMES fallback is the default for purposes with no explicit chance.
	assert_eq(RoomPurpose.DEFAULT_FOG_CHANCE, 0.08, "sometimes fallback chance")
	assert_eq(RoomData.new().fog_chance, 0.08, "purposeless rooms use the fallback")
	var fountain: RoomPurpose = load("res://scenes/worlds/world_gen/helper_objects/room_purposes/fountain_room.tres")
	var statue: RoomPurpose = load("res://scenes/worlds/world_gen/helper_objects/room_purposes/statue_gallery.tres")
	assert_eq(fountain.fog_chance, 0.95, "fountain fog chance")
	assert_eq(statue.fog_chance, 0.5, "statue fog chance: owner amendment 50 percent")
	var crypt: RoomPurpose = load("res://scenes/worlds/world_gen/helper_objects/room_purposes/crypt.tres")
	var trophy: RoomPurpose = load("res://scenes/worlds/world_gen/helper_objects/room_purposes/trophy_room.tres")
	assert_eq(crypt.fog_chance, 0.08, "crypt uses the fallback chance")
	assert_eq(trophy.fog_chance, 0.08, "trophy uses the fallback chance")


func test_fixed_seed_produces_deterministic_outcome():
	var data := _stat_data()
	var first := _make_run(TEST_SEED, data)
	var second := _make_run(TEST_SEED, data)
	assert_eq(first[0].captured_weather_scene_path, second[0].captured_weather_scene_path, "fog routing is seed-deterministic")
	assert_eq(first[1].captured_weather_scene_path, second[1].captured_weather_scene_path, "dust routing is seed-deterministic")
	assert_eq(first[0].captured_room_paths, second[0].captured_room_paths, "fog room paths are seed-deterministic")
	assert_eq(first[1].captured_room_paths, second[1].captured_room_paths, "dust room paths are seed-deterministic")


func test_roll_branch_matches_owner_model_for_fixed_seed():
	var prediction := _predict(TEST_SEED)
	var run := _make_run(TEST_SEED)
	var fog_observer = run[0]
	var dust_observer = run[1]
	assert_eq(dust_observer.captured_weather_scene_path, "", "fog family never gets dust routing")
	assert_true(
		fog_observer.captured_room_paths.is_empty() or dust_observer.captured_room_paths.is_empty(),
		"fog and dust never coexist on one floor")
	if prediction.family == "dust_type":
		assert_eq(fog_observer.captured_room_paths, {}, "no fog room paths on a dust-type floor")
	elif prediction.family == "special_all_dust":
		assert_eq(fog_observer.captured_room_paths, {}, "special all-dust floor routes no fog")


func test_fog_presence_follows_the_room_fog_rule():
	# Aggregated over many seeds on normal fog-type floors only: the fountain
	# fleet fogs at its per-purpose 0.95, the statue fleet at its 0.5, the
	# SOMETIMES fleet rarely, NEVER never.
	var fountain_fogged := 0
	var fountain_total := 0
	var statue_fogged := 0
	var statue_total := 0
	var sometimes_fogged := 0
	var sometimes_total := 0
	var never_fogged := 0
	var data := _stat_data()
	for seed in STAT_SEEDS:
		if _predict(seed).family != "fog_type":
			continue
		var run := _make_run(seed, data)
		var paths: Dictionary = run[0].captured_room_paths
		for room in data.get_all_rooms():
			var fogged: bool = paths.has(room)
			match room.type:
				RoomData.OriginalPurpose.FOUNTAIN:
					fountain_total += 1
					if fogged:
						fountain_fogged += 1
				RoomData.OriginalPurpose.STATUE_GALLERY:
					statue_total += 1
					if fogged:
						statue_fogged += 1
				RoomData.OriginalPurpose.CRYPT:
					sometimes_total += 1
					if fogged:
						sometimes_fogged += 1
				RoomData.OriginalPurpose.TROPHY_ROOM:
					if fogged:
						never_fogged += 1
	assert_gt(fountain_total, 100, "enough fountain-fleet samples observed")
	assert_gt(statue_total, 100, "enough statue-fleet samples observed")
	assert_gt(sometimes_total, 100, "enough sometimes-fleet samples observed")
	var fountain_rate := float(fountain_fogged) / float(fountain_total)
	var statue_rate := float(statue_fogged) / float(statue_total)
	var sometimes_rate := float(sometimes_fogged) / float(sometimes_total)
	assert_between(fountain_rate, 0.90, 1.0, "fountain rooms fog at their 0.95 rate")
	assert_between(statue_rate, 0.40, 0.60, "statue rooms fog at their 0.5 rate")
	assert_between(sometimes_rate, 0.02, 0.16, "sometimes rooms stay rare")
	assert_eq(never_fogged, 0, "never rooms stay clean")


func test_fog_variant_weights_match_the_consts():
	# Aggregated variant picks across fogged rooms on both fog paths: low
	# (half-height) most, medium (swirl) less, full (thick) rarely.
	var counts := [0, 0, 0]
	var data := _stat_data()
	for seed in STAT_SEEDS:
		if _predict(seed).family != "fog_type":
			continue
		var run := _make_run(seed, data)
		var variant_counts := _variant_counts(run[0].captured_room_paths)
		for index in 3:
			counts[index] += variant_counts[index]
	var total : int = counts[0] + counts[1] + counts[2]
	assert_gt(total, 100, "enough fogged rooms observed")
	var low := float(counts[0]) / float(total)
	var medium := float(counts[1]) / float(total)
	var full := float(counts[2]) / float(total)
	assert_between(low, 0.50, 0.70, "low variant share near 0.6")
	assert_between(medium, 0.20, 0.40, "medium variant share near 0.3")
	assert_between(full, 0.04, 0.18, "full variant share near 0.1")


func test_special_all_fog_floor_fogs_every_room_with_weighted_variants():
	var data := _stat_data()
	var checked := false
	for seed in STAT_SEEDS:
		if _predict(seed).family != "special_all_fog":
			continue
		checked = true
		var run := _make_run(seed, data)
		var paths: Dictionary = run[0].captured_room_paths
		assert_eq(paths.size(), data.get_all_rooms().size(),
			"special all-fog floor fogs every real room")
		assert_eq(run[0].captured_weather_scene_path, "",
			"special floors route per room now, not one floor-wide variant")
	assert_true(checked, "at least one special all-fog seed was exercised")


func test_fog_variant_pick_is_weighted_low_medium_full():
	var group = AtmosScript.new()
	group.fog_half_height_scene_path = FOG_VARIANTS[0]
	group.fog_swirl_scene_path = FOG_VARIANTS[1]
	group.fog_thick_scene_path = FOG_VARIANTS[2]
	# Replicate the weighted pick math on the same rng state as the group.
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	group._rng.seed = TEST_SEED
	var counts := [0, 0, 0]
	for _index in 900:
		var roll := rng.randf()
		var expected := FOG_VARIANTS[2]
		if roll < 0.6:
			expected = FOG_VARIANTS[0]
		elif roll < 0.9:
			expected = FOG_VARIANTS[1]
		assert_eq(group._pick_fog_variant(), expected, "weighted variant follows the consts")
	group.free()


func test_dust_variant_pick_keeps_its_uniform_roll():
	var group = AtmosScript.new()
	group.dust_scene_path = DUST_VARIANTS[0]
	group.flecks_scene_path = DUST_VARIANTS[1]
	group.plague_scene_path = DUST_VARIANTS[2]
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	group._rng.seed = TEST_SEED
	var dust_index := rng.randi() % 3
	assert_eq(group._pick_dust_variant(), DUST_VARIANTS[dust_index], "dust variant keeps randi % 3")
	group.free()


func test_purpose_fog_rule_flows_onto_rooms_end_to_end():
	# The real generate_room_purposes step with the real shipped .tres purposes
	# must carry each purpose's fog_rule onto the rooms it assigns, because the
	# atmosphere group's presence roll reads RoomData.fog_rule.
	var data := WorldData.new()
	data.resize(48, 48)
	var big_rects := [Rect2(2, 2, 7, 7), Rect2(2, 12, 7, 7), Rect2(2, 22, 8, 6)]
	var small_rects := [Rect2(14, 2, 4, 4), Rect2(14, 9, 3, 3), Rect2(14, 15, 4, 5)]
	for rect in big_rects:
		_add_room_with_doorways(data, rect, 2)
	for rect in small_rects:
		_add_room_with_doorways(data, rect, 1)
	var purpose_step = load(
		"res://scenes/worlds/world_gen/generation_steps/generate_room_purposes.gd").new()
	add_child_autofree(purpose_step)
	purpose_step.purpose_resources = [
		load("res://scenes/worlds/world_gen/helper_objects/room_purposes/crypt.tres"),
		load("res://scenes/worlds/world_gen/helper_objects/room_purposes/fountain_room.tres"),
		load("res://scenes/worlds/world_gen/helper_objects/room_purposes/statue_gallery.tres"),
		load("res://scenes/worlds/world_gen/helper_objects/room_purposes/trophy_room.tres"),
	]
	purpose_step._execute_step(data, {}, 777)
	var assigned := 0
	for room in data.get_all_rooms():
		match room.type:
			RoomData.OriginalPurpose.FOUNTAIN:
				assert_eq(room.fog_rule, RoomPurpose.FogRule.OFTEN,
					"assigned fountain room carries the OFTEN rule")
				assert_eq(room.fog_chance, 0.95, "fountain chance copied from the purpose")
				assigned += 1
			RoomData.OriginalPurpose.STATUE_GALLERY:
				assert_eq(room.fog_rule, RoomPurpose.FogRule.OFTEN,
					"assigned statue room carries the OFTEN rule")
				assert_eq(room.fog_chance, 0.5, "statue chance copied from the purpose")
				assigned += 1
			RoomData.OriginalPurpose.CRYPT, RoomData.OriginalPurpose.TROPHY_ROOM:
				assert_eq(room.fog_rule, RoomPurpose.FogRule.SOMETIMES,
					"assigned default-purpose room carries the SOMETIMES rule")
				assert_eq(room.fog_chance, 0.08, "default-purpose room uses the fallback chance")
				assigned += 1
	assert_gt(assigned, 0, "at least one purpose was assigned to a room")


func _add_room_with_doorways(data : WorldData, rect : Rect2, doorway_count : int) -> void:
	data.fill_room_data(rect, RoomData.OriginalPurpose.EMPTY)
	# fill_room_data appends the new room last in the EMPTY list.
	var room: RoomData = data.get_rooms_of_type(RoomData.OriginalPurpose.EMPTY).back()
	var doorways := {}
	for direction in doorway_count:
		doorways[direction] = [room.cell_indexes[0]]
	room._doorways = doorways
