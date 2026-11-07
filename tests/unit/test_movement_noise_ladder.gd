extends GutTest
## Movement noise ladder (owner-approved) on HumanoidCharacter: walk
## stone/gravel/carpet = 6/9/3, sprint = 12/14/6 (sprint carpet equals walk
## stone), crouch-walk silent (no producer), jump landing 10 via
## apply_landing_noise with the crouch-landing exception left silent.

const HumanoidCharacterScript = preload("res://scenes/characters/humanoid_character_base/humanoid_character.gd")


func test_walk_ladder_per_material() -> void:
	assert_eq(HumanoidCharacterScript.movement_noise_for(AudioLibrary.FOOTSTEP_TYPES.STONE, false), 6.0)
	assert_eq(HumanoidCharacterScript.movement_noise_for(AudioLibrary.FOOTSTEP_TYPES.GRAVEL, false), 9.0)
	assert_eq(HumanoidCharacterScript.movement_noise_for(AudioLibrary.FOOTSTEP_TYPES.CARPET, false), 3.0)


func test_sprint_ladder_per_material() -> void:
	assert_eq(HumanoidCharacterScript.movement_noise_for(AudioLibrary.FOOTSTEP_TYPES.STONE, true), 12.0)
	assert_eq(HumanoidCharacterScript.movement_noise_for(AudioLibrary.FOOTSTEP_TYPES.GRAVEL, true), 14.0)
	assert_eq(HumanoidCharacterScript.movement_noise_for(AudioLibrary.FOOTSTEP_TYPES.CARPET, true), 6.0,
		"sprint carpet equals the walk stone level")


func test_unknown_material_is_silent() -> void:
	# The resolver only emits stone, gravel and carpet; anything else is
	# silent rather than falling back to stone.
	assert_eq(HumanoidCharacterScript.movement_noise_for(99, false), 0.0)


func test_crouch_walk_has_no_producer_value() -> void:
	# Crouch-walk is silent by design: the ladder carries no crouch entry and
	# the producer writes nothing for a crouched step. Pinned as a constant
	# check so a future ladder entry cannot appear by accident unnoticed.
	assert_false(HumanoidCharacterScript.WALK_NOISE.has("crouch"), "no crouch entry in the ladder")


func test_landing_noise_is_ten() -> void:
	var body : Node = HumanoidCharacterScript.new()
	autofree(body)
	body.apply_landing_noise()
	assert_eq(body.noise_level, 10.0, "jump landing sets the landing noise level")
