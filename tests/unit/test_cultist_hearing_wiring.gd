extends GutTest
## Cultist hearing wiring: the neophyte's StimulusAdapter lists the
## SoundSensor among its active_sensors, so the sensor's
## event(interest, position, object, emitter) signal feeds the adapter's
## _on_sensor_event handler and lands on the blackboard. The sensor surface
## itself is untouched; only the consuming brain changed in the HFSM cutover.

const NEOPHYTE_SCENE := "res://scenes/characters/cultist/neophyte.tscn"

var _cultist : Node


func after_each() -> void:
	if is_instance_valid(_cultist):
		_cultist.free()
	_cultist = null


func _stimulus_adapter() -> Node:
	var adapters : Array[Node] = _cultist.find_children("*", "StimulusAdapter", true, false)
	return adapters[0] if not adapters.is_empty() else null


func _sound_sensor() -> Node:
	var sensors : Array[Node] = _cultist.find_children("*", "SoundSensor", true, false)
	return sensors[0] if not sensors.is_empty() else null


func test_neophyte_lists_the_sound_sensor_among_active_sensors() -> void:
	_cultist = (load(NEOPHYTE_SCENE) as PackedScene).instantiate()
	add_child(_cultist)
	var adapter : Node = _stimulus_adapter()
	assert_not_null(adapter, "the neophyte carries a StimulusAdapter under the Brain")
	var sensor : Node = _sound_sensor()
	assert_not_null(sensor, "the neophyte carries a SoundSensor under Sensors")
	var sensors_list : Array = adapter.active_sensors
	var has_sensor := false
	for entry in sensors_list:
		if entry == sensor:
			has_sensor = true
	assert_true(has_sensor,
		"the StimulusAdapter's active_sensors resolve the SoundSensor node")
	assert_eq(sensors_list.size(), 3, "visual, touch and sound sensors are all active")


func test_sound_sensor_event_reaches_the_blackboard_through_the_adapter() -> void:
	_cultist = (load(NEOPHYTE_SCENE) as PackedScene).instantiate()
	add_child(_cultist)
	var controller : Node = _cultist.get_node("AIController")
	var adapter : Node = _stimulus_adapter()
	var sensor : Node = _sound_sensor()
	var bystander := Node3D.new()
	add_child(bystander)
	sensor.event.emit(25, Vector3(1.0, 0.0, 0.0), bystander, sensor)
	var board: Blackboard = controller.ai_state
	assert_almost_eq(board.alertness, 25.0, 0.001,
		"the sensor event lands on the controller's blackboard")
	assert_eq(board.last_stimulus.kind, Blackboard.StimulusKind.SOUND)
	bystander.free()


func test_sound_sensor_event_signature_matches_the_adapter_handler() -> void:
	# SoundSensor emits event(interest, position, object, self); the adapter
	# handler takes (interest: int, position: Vector3, object, emitter).
	# Pin the arg count so a signature drift surfaces here.
	var sensor_script : GDScript = load("res://scenes/sensors/sound_sensor.gd")
	var signal_list : Array[Dictionary] = sensor_script.get_script_signal_list()
	var found := false
	for sig in signal_list:
		if sig["name"] == "event":
			found = true
			assert_eq(int(sig["args"].size()), 4,
				"the sensor event signal carries interest, position, object, emitter")
	assert_true(found, "the SoundSensor declares an event signal")
