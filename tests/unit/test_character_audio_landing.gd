extends GutTest
## Jump landing must play the dedicated landing clip from
## resources/sounds/jumping_landing/landing at its own pitch and volume.
## Regression context (issue #41 followup): the footstep path shares the
## Movement AudioStreamPlayer3D and leaves its own pitch (1.5 sprint, 0.1
## crouch) and volume (+5.0 rate) behind; play_land_sound used to inherit
## those leftovers, so jump landing sounded like a wrong footstep clip.

const CHARACTER_AUDIO_SCRIPT := "res://scenes/characters/character_audio.gd"
const LANDING_DIR := "res://resources/sounds/jumping_landing/landing/"
const FOOTSTEP_DIR := "res://resources/sounds/footsteps/stone_footsteps/"
const LAND_CLIP := "res://resources/sounds/jumping_landing/landing/land_1.wav"

var _audio : Node3D


func before_each() -> void:
	_audio = Node3D.new()
	_audio.set_script(load(CHARACTER_AUDIO_SCRIPT))
	for child_name in ["Speech", "Manipulation", "Movement"]:
		var player := AudioStreamPlayer3D.new()
		player.name = child_name
		_audio.add_child(player)
	# add_child triggers _ready, which runs the DirAccess scan of the
	# landing folder through the new load_sounds loader.
	add_child_autofree(_audio)


func after_each() -> void:
	if is_instance_valid(_audio):
		_audio.movement_audio.stop()


func test_landing_loader_fills_landing_array_from_landing_folder() -> void:
	var landing_sounds : Array = _audio._landing_sounds
	assert_gt(landing_sounds.size(), 0, "the landing folder scan loaded at least one stream")
	for stream in landing_sounds:
		assert_true(String(stream.resource_path).begins_with(LANDING_DIR),
			"loaded landing stream lives in the landing folder: " + String(stream.resource_path))


func test_land_sound_plays_dedicated_landing_clip() -> void:
	_audio.play_land_sound()
	var movement : AudioStreamPlayer3D = _audio.movement_audio
	assert_true(movement.playing, "the land sound is playing")
	assert_eq(String(movement.stream.resource_path), LAND_CLIP,
		"the stream is the dedicated landing clip, not a footstep clip")


func test_land_sound_overrides_sprint_footstep_pitch_and_volume() -> void:
	# A sprint footstep right before the jump leaves pitch 1.5 and +5 dB on
	# the shared Movement player, exactly as in the live game.
	_audio.play_footstep_sound(5.0, 1.5)
	var movement : AudioStreamPlayer3D = _audio.movement_audio
	assert_true(String(movement.stream.resource_path).begins_with(FOOTSTEP_DIR),
		"the walking sound comes from the material footstep folder")
	assert_eq(movement.pitch_scale, 1.5, "precondition: sprint footstep pitch is 1.5")
	_audio.play_land_sound()
	assert_eq(String(movement.stream.resource_path), LAND_CLIP,
		"landing plays the dedicated landing clip after a sprint footstep")
	assert_eq(movement.pitch_scale, 1.0, "landing resets pitch to natural")
	assert_eq(movement.volume_db, 0.0, "landing resets volume to the 3.x land volume")


func test_land_sound_overrides_crouch_footstep_pitch_and_volume() -> void:
	# Crouch footsteps leave pitch 0.1 on the shared player; the land clip
	# at that pitch plays ten times slower and is unrecognizable.
	_audio.play_footstep_sound(-1.0, 0.1, -20)
	var movement : AudioStreamPlayer3D = _audio.movement_audio
	# pitch_scale stores 0.1 as float32 (0.10000000149...), so compare loosely
	assert_almost_eq(movement.pitch_scale, 0.1, 0.0001, "precondition: crouch footstep pitch is 0.1")
	_audio.play_land_sound()
	assert_eq(String(movement.stream.resource_path), LAND_CLIP,
		"landing plays the dedicated landing clip after a crouch footstep")
	assert_eq(movement.pitch_scale, 1.0, "landing resets pitch to natural")
	assert_eq(movement.volume_db, 0.0, "landing resets volume to the 3.x land volume")
