extends GutTest
## Jump landing must play the dedicated landing clip from
## resources/sounds/jumping_landing/landing exactly like 3.x (origin/main):
## land_1.wav inherits the pitch and volume the footstep path left on the
## shared Movement player, and play_footstep_sound ends by applying its
## volume param (0.0 walk/sprint, -20.0 crouch) the way 3.x's double
## unit_db assignment did. The land_1.wav asset is blob-identical to
## origin/main; the wrong landing audio was the dropped footstep reset.

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
		if is_instance_valid(_audio._land_clamber_audio):
			_audio._land_clamber_audio.stop()


func test_landing_loader_fills_landing_array_from_landing_folder() -> void:
	var landing_sounds : Array = _audio._landing_sounds
	assert_gt(landing_sounds.size(), 0, "the landing folder scan loaded at least one stream")
	for stream in landing_sounds:
		assert_true(String(stream.resource_path).begins_with(LANDING_DIR),
			"loaded landing stream lives in the landing folder: " + String(stream.resource_path))


func test_land_sound_plays_dedicated_landing_clip() -> void:
	# Issue #179: landing rides the Reverb bus send player, not the shared
	# Movement player, so the footstep path stays untouched and nothing
	# plays twice.
	_audio.play_land_sound()
	var land : AudioStreamPlayer3D = _audio._land_clamber_audio
	assert_true(land.playing, "the land sound is playing")
	assert_eq(String(land.stream.resource_path), LAND_CLIP,
		"the stream is the dedicated landing clip, not a footstep clip")
	assert_eq(land.pitch_scale, 1.0, "with no footstep yet the land clip plays at natural pitch")
	assert_eq(land.volume_db, 0.0, "with no footstep yet the land clip plays at 0 dB")
	assert_false(_audio.movement_audio.playing, "the Movement player does not double-play the landing")


func test_land_clamber_send_targets_the_reverb_bus() -> void:
	assert_not_null(_audio._land_clamber_audio, "the send player exists")
	assert_eq(_audio._land_clamber_audio.bus, "Reverb", "the send player targets the Reverb bus")


func test_footstep_volume_resets_like_3x() -> void:
	# 3.x assigned unit_db twice: rate then the volume param. The walking
	# call passes rate 5.0 but must still end at 0 dB, matching main.
	_audio.play_footstep_sound(5.0, 1.0)
	var movement : AudioStreamPlayer3D = _audio.movement_audio
	assert_true(String(movement.stream.resource_path).begins_with(FOOTSTEP_DIR),
		"the walking sound comes from the material footstep folder")
	assert_eq(movement.pitch_scale, 1.0, "walk footstep pitch is 1.0")
	assert_eq(movement.volume_db, 0.0, "walk footstep ends at the 3.x 0 dB volume")


func test_land_sound_after_walk_matches_3x() -> void:
	_audio.play_footstep_sound(5.0, 1.0)
	_audio.play_land_sound()
	var land : AudioStreamPlayer3D = _audio._land_clamber_audio
	assert_eq(String(land.stream.resource_path), LAND_CLIP,
		"landing plays the dedicated landing clip after a walk footstep")
	assert_eq(land.pitch_scale, 1.0, "3.x walk landing pitch")
	assert_eq(land.volume_db, 0.0, "3.x walk landing volume")


func test_land_sound_after_sprint_matches_3x() -> void:
	# 3.x sprint footsteps ran at pitch 1.5 and 0 dB, so a sprint landing
	# inherited that: the sharper heel clap the owner remembers.
	_audio.play_footstep_sound(5.0, 1.5)
	_audio.play_land_sound()
	var land : AudioStreamPlayer3D = _audio._land_clamber_audio
	assert_eq(String(land.stream.resource_path), LAND_CLIP,
		"landing plays the dedicated landing clip after a sprint footstep")
	assert_eq(land.pitch_scale, 1.5, "3.x sprint landing pitch")
	assert_eq(land.volume_db, 0.0, "3.x sprint landing volume")


func test_land_sound_after_crouch_matches_3x() -> void:
	# 3.x crouch footsteps ran at pitch 0.1 and -20 dB, so a landing right
	# after crouching was effectively silent, exactly like main.
	_audio.play_footstep_sound(-1.0, 0.1, -20.0)
	_audio.play_land_sound()
	var land : AudioStreamPlayer3D = _audio._land_clamber_audio
	assert_eq(String(land.stream.resource_path), LAND_CLIP,
		"landing plays the dedicated landing clip after a crouch footstep")
	# pitch_scale stores 0.1 as float32 (0.10000000149...), so compare loosely
	assert_almost_eq(land.pitch_scale, 0.1, 0.0001, "3.x crouch landing pitch")
	assert_eq(land.volume_db, -20.0, "3.x crouch landing volume (silent)")


func test_clamber_sound_plays_on_the_send_player() -> void:
	var clamber_stream : AudioStream = load(LAND_CLIP)
	_audio._clamber_sounds["in"] = [clamber_stream]
	_audio.play_clamber_sound(true)
	var land : AudioStreamPlayer3D = _audio._land_clamber_audio
	assert_true(land.playing, "the clamber sound is playing")
	assert_eq(land.stream, clamber_stream, "the clamber sound plays its injected clip")
	assert_false(_audio.movement_audio.playing, "the Movement player does not double-play the clamber")
