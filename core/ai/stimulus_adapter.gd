class_name StimulusAdapter
extends Node

## Consumes the sensors' event(interest, position, object, emitter) signals,
## exactly like the BT's InterestMachine did, and converts each event into a
## blackboard stimulus. The noise system is consumed as-is: a SoundSensor
## event arrives already filtered by wall count and sensitivity; the adapter
## only classifies the stimulus kind from the emitter and the object.
## Stimulus kinds: a VisualSensor event is SIGHT for a player or other
## object, LIGHT when the object is a light area; SoundSensor is SOUND,
## TouchSensor is TOUCH, anything else INTERACT.


@export var active_sensors: Array[CharacterSense] = []

var blackboard: Blackboard = null


func _ready() -> void:
	_connect_sensors()


## Assign the blackboard and connect any sensors not yet connected.
func setup(blackboard_ref: Blackboard) -> void:
	blackboard = blackboard_ref
	_connect_sensors()


## Debug and test entry point: inject a synthetic perception event into the
## blackboard without a sensor.
func simulate_stimulus(kind: Blackboard.StimulusKind, position: Vector3, interest: float, object: Object = null) -> void:
	if blackboard == null:
		push_warning("StimulusAdapter: no blackboard, stimulus dropped")
		return
	blackboard.apply_stimulus(kind, interest, position, object)


func _connect_sensors() -> void:
	for sensor in active_sensors:
		if sensor != null and not sensor.event.is_connected(_on_sensor_event):
			sensor.event.connect(_on_sensor_event)


func _on_sensor_event(interest: int, position: Vector3, object: Object, emitter: CharacterSense) -> void:
	if blackboard == null:
		push_warning("StimulusAdapter: sensor event before setup, stimulus dropped")
		return
	blackboard.apply_stimulus(kind_for(emitter, object), float(interest), position, object)


func kind_for(emitter: CharacterSense, object: Object) -> Blackboard.StimulusKind:
	if emitter is SoundSensor:
		return Blackboard.StimulusKind.SOUND
	if emitter is TouchSensor:
		return Blackboard.StimulusKind.TOUCH
	if emitter is VisualSensor:
		if object is LightArea:
			return Blackboard.StimulusKind.LIGHT
		return Blackboard.StimulusKind.SIGHT
	return Blackboard.StimulusKind.INTERACT
