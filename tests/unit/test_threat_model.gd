extends GutTest

## Threat model semantics on the blackboard: stimulus kind weighting, the
## investigate and combat bars, alertness decay after the attention span,
## the sight-of-player combat conclusion, and the StimulusAdapter routing
## sensor events by emitter.

const H := preload("res://tests/unit/hfsm_test_harness.gd")

var board: Blackboard


func before_each() -> void:
	board = Blackboard.new()


func after_each() -> void:
	board = null


func test_stimulus_kinds_are_weighted_differently() -> void:
	board.apply_stimulus(Blackboard.StimulusKind.SIGHT, 40.0, Vector3.ZERO)
	assert_almost_eq(board.alertness, 40.0, 0.001, "sight maps interest directly")
	board = Blackboard.new()
	board.apply_stimulus(Blackboard.StimulusKind.SOUND, 40.0, Vector3.ZERO)
	assert_almost_eq(board.alertness, 40.0, 0.001, "sound maps interest directly")
	board = Blackboard.new()
	board.apply_stimulus(Blackboard.StimulusKind.LIGHT, 40.0, Vector3.ZERO)
	assert_almost_eq(board.alertness, 20.0, 0.001, "light is halved per the owner's light policy")
	board = Blackboard.new()
	board.apply_stimulus(Blackboard.StimulusKind.TOUCH, 40.0, Vector3.ZERO)
	assert_almost_eq(board.alertness, 40.0, 0.001, "touch maps interest directly")
	board = Blackboard.new()
	board.apply_stimulus(Blackboard.StimulusKind.INTERACT, 40.0, Vector3.ZERO)
	assert_almost_eq(board.alertness, 20.0, 0.001, "interact is halved")


func test_alertness_clamps_at_100() -> void:
	board.apply_stimulus(Blackboard.StimulusKind.TOUCH, 300.0, Vector3.ZERO)
	assert_almost_eq(board.alertness, 100.0, 0.001)


func test_the_investigate_and_combat_bars_bound_the_bands() -> void:
	board.alertness = 29.9
	assert_false(board.alert_reaches_investigate())
	board.alertness = 30.0
	assert_true(board.alert_reaches_investigate(), "at the bar counts")
	board.alertness = 69.9
	assert_false(board.alert_reaches_combat())
	board.alertness = 70.0
	assert_true(board.alert_reaches_combat(), "at the bar counts")


func test_sight_of_the_player_concludes_the_player() -> void:
	var player := H.bare_player()
	board.apply_stimulus(Blackboard.StimulusKind.SIGHT, 300.0, Vector3(1.0, 2.0, 3.0), player)
	assert_eq(board.target, player, "direct sight names the target")
	assert_true(board.alert_reaches_combat(), "and floors alertness at the combat bar")
	assert_eq(board.last_stimulus.position, Vector3(1.0, 2.0, 3.0))
	player.free()


func test_sound_light_and_touch_never_conclude_the_player() -> void:
	var player := H.bare_player()
	board.apply_stimulus(Blackboard.StimulusKind.SOUND, 300.0, Vector3.ZERO, player)
	assert_null(board.target, "a sound never names the player")
	board.apply_stimulus(Blackboard.StimulusKind.TOUCH, 300.0, Vector3.ZERO, player)
	assert_null(board.target, "a touch never names the player")
	board.apply_stimulus(Blackboard.StimulusKind.LIGHT, 300.0, Vector3.ZERO, player)
	assert_null(board.target, "a light never names the player (owner policy)")
	player.free()


func test_alertness_holds_for_the_attention_span_then_decays() -> void:
	board.apply_stimulus(Blackboard.StimulusKind.SOUND, 50.0, Vector3.ZERO)
	for i in 50:
		board.tick(0.1)
	assert_almost_eq(board.alertness, 50.0, 0.001, "exactly the attention span holds")
	board.tick(0.1)
	assert_almost_eq(board.alertness, 49.0, 0.001, "decay starts past the span at decay_rate")
	for i in 49:
		board.tick(0.1)
	assert_almost_eq(board.alertness, 0.0, 0.001, "and decays to calm")


func test_a_new_stimulus_renews_attention() -> void:
	board.apply_stimulus(Blackboard.StimulusKind.SOUND, 50.0, Vector3.ZERO)
	for i in 40:
		board.tick(0.1)
	board.apply_stimulus(Blackboard.StimulusKind.SOUND, 20.0, Vector3(1.0, 0.0, 0.0))
	assert_almost_eq(board.alertness, 70.0, 0.001, "the renewal raises alertness further")
	for i in 49:
		board.tick(0.1)
	assert_almost_eq(board.alertness, 70.0, 0.001, "the new stimulus resets the attention span")


func test_percepts_keep_the_strongest_event_per_object() -> void:
	var first := Node3D.new()
	var second := Node3D.new()
	board.apply_stimulus(Blackboard.StimulusKind.SOUND, 10.0, Vector3.ZERO, first)
	board.apply_stimulus(Blackboard.StimulusKind.SOUND, 25.0, Vector3(1.0, 0.0, 0.0), first)
	board.apply_stimulus(Blackboard.StimulusKind.SIGHT, 60.0, Vector3(2.0, 0.0, 0.0), second)
	assert_eq(board.percepts.size(), 2)
	var percept: Blackboard.Percept = board.percepts[first]
	assert_almost_eq(percept.interest, 25.0, 0.001, "the stronger event wins the object")
	assert_eq(percept.position, Vector3(1.0, 0.0, 0.0))
	assert_eq(board.most_interesting_percept().object, second)
	first.free()
	second.free()


func test_freed_percepts_are_pruned_on_tick() -> void:
	var object := Node3D.new()
	board.apply_stimulus(Blackboard.StimulusKind.SOUND, 10.0, Vector3.ZERO, object)
	object.free()
	board.tick(0.1)
	assert_eq(board.percepts.size(), 0, "a freed source drops out of the map")


func test_stimulus_adapter_routes_sensor_events_by_emitter() -> void:
	var sound_sensor := SoundSensor.new()
	var visual_sensor := VisualSensor.new()
	var adapter := StimulusAdapter.new()
	adapter.active_sensors = [sound_sensor, visual_sensor]
	add_child(adapter)
	adapter.setup(board)
	var bystander := Node3D.new()
	sound_sensor.event.emit(25, Vector3(1.0, 0.0, 0.0), bystander, sound_sensor)
	assert_almost_eq(board.alertness, 25.0, 0.001, "a sound event lands on the blackboard")
	assert_eq(board.last_stimulus.kind, Blackboard.StimulusKind.SOUND)
	var light_area := LightArea.new()
	visual_sensor.event.emit(75, Vector3(2.0, 0.0, 0.0), light_area, visual_sensor)
	assert_eq(board.last_stimulus.kind, Blackboard.StimulusKind.LIGHT,
		"a light sighting through the visual sensor classifies as light")
	assert_almost_eq(board.alertness, 25.0 + 37.5, 0.001, "light is weighted at half")
	var player := H.bare_player()
	visual_sensor.event.emit(300, Vector3(3.0, 0.0, 0.0), player, visual_sensor)
	assert_eq(board.target, player, "a player sighting through the visual sensor concludes the player")
	assert_eq(board.last_stimulus.kind, Blackboard.StimulusKind.SIGHT)
	player.free()
	light_area.collision_shape.free()
	light_area.free()
	bystander.free()
	sound_sensor.free()
	visual_sensor.free()
	adapter.free()


func test_stimulus_adapter_simulate_stimulus_injects_without_a_sensor() -> void:
	var adapter := StimulusAdapter.new()
	add_child(adapter)
	adapter.setup(board)
	adapter.simulate_stimulus(Blackboard.StimulusKind.SOUND, Vector3(4.0, 0.0, 0.0), 10.0)
	assert_almost_eq(board.alertness, 10.0, 0.001)
	assert_eq(board.last_stimulus.position, Vector3(4.0, 0.0, 0.0))
	adapter.free()
