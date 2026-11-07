# Tests for the room-size to reverb parameter mapping and the shared "Reverb"
# bus wiring (issue #179). The mapping is pure logic on RoomReverbArea
# (static, no node needed); the bus is real AudioServer state created at
# runtime, so the wiring tests assert on AudioServer itself. The default
# params must never be silence: dry stays 1.0 everywhere.
extends GutTest

const ReverbScript = preload("res://scenes/effects/room_reverb_area.gd")


func after_each() -> void:
	# Restore the small default tail so other tests and the running game are
	# not left with a hall-sized reverb. Skipped when the bus was never
	# created in this test, so the cleanup itself emits no warnings.
	if AudioServer.get_bus_index("Reverb") != -1:
		ReverbScript.apply_reverb_params(ReverbScript.default_params())


func _params_for(size_meters : Vector2) -> Dictionary:
	return ReverbScript.params_for_room_size(size_meters)


func test_params_grow_monotonically_with_room_size():
	var small := _params_for(Vector2(4.5, 4.5))
	var medium := _params_for(Vector2(12.0, 6.0))
	var large := _params_for(Vector2(24.0, 18.0))
	assert_lt(small["wet"], medium["wet"], "wet grows with room size")
	assert_lt(medium["wet"], large["wet"], "wet grows with room size")
	assert_lt(small["room_size"], medium["room_size"], "room_size grows with room size")
	assert_lt(medium["room_size"], large["room_size"], "room_size grows with room size")
	assert_lt(small["predelay_msec"], large["predelay_msec"], "predelay grows with room size")
	assert_lt(small["damping"], large["damping"], "bigger rooms have a darker tail")


func test_params_are_clamped_to_the_mapping_range():
	var huge := _params_for(Vector2(300.0, 300.0))
	var large_endpoint := _params_for(Vector2(24.0, 24.0))
	assert_eq(huge, large_endpoint, "sizes beyond the range clamp to the large endpoint")
	var tiny := _params_for(Vector2(0.5, 0.5))
	var small_endpoint := _params_for(Vector2(3.0, 3.0))
	assert_eq(tiny, small_endpoint, "sizes below the range clamp to the small endpoint")


func test_dry_is_always_full_so_the_default_is_never_silence():
	assert_eq(_params_for(Vector2(24.0, 24.0))["dry"], 1.0, "room params keep dry full")
	assert_eq(ReverbScript.default_params()["dry"], 1.0, "default params keep dry full")


func test_defaults_are_a_small_nearly_dry_room():
	var defaults := ReverbScript.default_params()
	var small_room := _params_for(Vector2(3.0, 3.0))
	assert_lt(defaults["wet"], small_room["wet"], "no-room default is drier than the smallest room")
	assert_lt(defaults["room_size"], small_room["room_size"], "no-room default is tighter")


func test_ensure_reverb_bus_is_idempotent_and_wired_to_effects():
	var first : int = ReverbScript.ensure_reverb_bus()
	var second : int = ReverbScript.ensure_reverb_bus()
	assert_eq(first, second, "ensure_reverb_bus returns the same bus index")
	assert_gte(first, 0, "reverb bus exists")
	assert_eq(AudioServer.get_bus_name(first), "Reverb", "bus is named Reverb")
	assert_eq(AudioServer.get_bus_send(first), "Effects", "reverb sends into Effects for the volume slider")
	assert_true(AudioServer.get_bus_effect(first, 0) is AudioEffectReverb, "bus carries a reverb effect")


func test_apply_reverb_params_is_observable_on_the_bus():
	var bus : int = ReverbScript.ensure_reverb_bus()
	var reverb : AudioEffectReverb = AudioServer.get_bus_effect(bus, 0)
	var params := _params_for(Vector2(24.0, 18.0))
	ReverbScript.apply_reverb_params(params)
	assert_almost_eq(reverb.wet, params["wet"], 0.0001, "wet applied to the shared effect")
	assert_almost_eq(reverb.room_size, params["room_size"], 0.0001, "room_size applied")
	assert_almost_eq(reverb.damping, params["damping"], 0.0001, "damping applied")
	assert_almost_eq(reverb.predelay_msec, params["predelay_msec"], 0.0001, "predelay applied")
	assert_almost_eq(reverb.dry, 1.0, 0.0001, "dry stays full")


func test_area_scene_builds_the_room_box_and_detection_wiring():
	var scene : PackedScene = load("res://scenes/effects/room_reverb_area.tscn")
	assert_not_null(scene, "reverb area scene loads")
	var area = scene.instantiate()
	area.size = Vector3(7.0, 3.4, 6.0)
	add_child_autofree(area)
	assert_eq(area.get_class(), "Area3D", "root is an Area3D")
	assert_eq(area.collision_layer, 0, "nothing else queries the area")
	assert_eq(area.collision_mask, 2, "area watches the Player layer")
	assert_true(area.is_in_group("room_reverb_areas"), "area joins the shared room group")
	var shape : BoxShape3D = area.get_node("CollisionShape3D").shape
	assert_eq(shape.size, Vector3(7.0, 3.4, 6.0), "box shape matches the room footprint")
	area.free()


func test_breathing_rides_the_reverb_bus_in_character_audio_setup():
	# Observable routing: the player's breathing player must target the
	# "Reverb" bus, and setup must create the bus and reset defaults.
	# _setup_breathing is called directly and the node is never added to the
	# tree, so the scene-child @onready vars are not touched.
	var character_audio = preload("res://scenes/characters/character_audio.gd").new()
	character_audio._setup_breathing()
	assert_not_null(character_audio._breathing_audio, "setup creates the breathing player")
	assert_eq(character_audio._breathing_audio.bus, "Reverb", "breathing player targets the Reverb bus")
	var bus : int = ReverbScript.ensure_reverb_bus()
	var reverb : AudioEffectReverb = AudioServer.get_bus_effect(bus, 0)
	assert_almost_eq(reverb.dry, 1.0, 0.0001, "setup reset leaves dry full")
	character_audio.free()
