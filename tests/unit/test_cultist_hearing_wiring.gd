extends GutTest
## Cultist hearing wiring: the neophyte's BTInterestMachine lists the
## SoundSensor among its active_sensors, so the sensor's
## event(interest, position, object, emitter) signal feeds the machine's
## set_event(interest: int, position: Vector3, object: Object,
## emitter: CharacterSense) handler. AI behavior code is untouched.

const NEOPHYTE_SCENE := "res://scenes/characters/cultist/neophyte.tscn"

var _cultist : Node


func after_each() -> void:
	if is_instance_valid(_cultist):
		_cultist.free()
	_cultist = null


func _interest_machine() -> Node:
	var machines : Array[Node] = _cultist.find_children("*", "BTInterestMachine", true, false)
	return machines[0] if not machines.is_empty() else null


func _sound_sensor() -> Node:
	var sensors : Array[Node] = _cultist.find_children("*", "SoundSensor", true, false)
	return sensors[0] if not sensors.is_empty() else null


func test_neophyte_lists_the_sound_sensor_among_active_sensors() -> void:
	_cultist = (load(NEOPHYTE_SCENE) as PackedScene).instantiate()
	add_child(_cultist)
	var machine : Node = _interest_machine()
	assert_not_null(machine, "the neophyte carries a BTInterestMachine")
	var sensor : Node = _sound_sensor()
	assert_not_null(sensor, "the neophyte carries a SoundSensor under Sensors")
	var paths : Array = machine.active_sensors
	var has_sensor := false
	for entry in paths:
		if entry == sensor:
			has_sensor = true
	assert_true(has_sensor,
		"the InterestMachine's active_sensors resolve the SoundSensor node")
	assert_eq(paths.size(), 3, "visual, touch and sound sensors are all active")


func test_sound_sensor_event_signature_matches_the_machine_handler() -> void:
	# SoundSensor emits event(interest, position, object, self); the machine
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
