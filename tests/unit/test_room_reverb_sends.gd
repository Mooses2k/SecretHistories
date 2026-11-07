# Tests for the optional sends into the shared "Reverb" bus (issue #179,
# docs/research/room_reverb_report.md section 6). Each send must keep its dry
# signal at full volume through the bus reverb's dry = 1.0 and only gain the
# room-driven wet tail. Assertions are on real AudioServer state and on the
# routed players' bus property.
extends GutTest

const ReverbScript = preload("res://scenes/effects/room_reverb_area.gd")
const CharacterAudioScript = preload("res://scenes/characters/character_audio.gd")

var _audio : Node3D


func after_each() -> void:
	# Restore the small default tail so other tests and the running game are
	# not left with a hall-sized reverb. Skipped when the bus was never
	# created in this test, so the cleanup itself emits no warnings.
	if AudioServer.get_bus_index("Reverb") != -1:
		ReverbScript.apply_reverb_params(ReverbScript.default_params())


func _make_character_audio() -> void:
	_audio = Node3D.new()
	_audio.set_script(load("res://scenes/characters/character_audio.gd"))
	for child_name in ["Speech", "Manipulation", "Movement"]:
		var player := AudioStreamPlayer3D.new()
		player.name = child_name
		_audio.add_child(player)
	add_child_autofree(_audio)


func test_speech_rides_the_reverb_bus():
	_make_character_audio()
	assert_not_null(_audio.speech_audio, "the Speech player resolves")
	assert_eq(_audio.speech_audio.bus, "Reverb", "speech player targets the Reverb bus")
	var bus : int = ReverbScript.ensure_reverb_bus()
	assert_gte(bus, 0, "speech routing created the shared reverb bus")
	assert_eq(AudioServer.get_bus_send(bus), "Effects", "reverb sends into Effects for the volume slider")


func test_speech_routing_keeps_dry_full_and_leaves_room_params_alone():
	var bus : int = ReverbScript.ensure_reverb_bus()
	var reverb : AudioEffectReverb = AudioServer.get_bus_effect(bus, 0)
	ReverbScript.apply_reverb_params(ReverbScript.params_for_room_size(Vector2(24.0, 18.0)))
	var wet_before : float = reverb.wet
	_make_character_audio()
	assert_almost_eq(reverb.dry, 1.0, 0.0001, "speech routing keeps dry full")
	assert_almost_eq(reverb.wet, wet_before, 0.0001, "speech routing never resets the room params")
