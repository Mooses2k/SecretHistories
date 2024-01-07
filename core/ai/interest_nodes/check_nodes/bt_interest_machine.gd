class_name BTInterestMachine extends BTCheck


signal player_detected(player, position)
signal indirect_event_detected()

export var detection_threshold := 0.8
export var attention_span := 5.0
export var decay_rate := 2.0

var events := {}


class Event:
	var emitter: CharacterSense = null
	var position := Vector3.ZERO
	var interest := 0.0
	var object: Object
	
	var time := 0.0
	
	func _init(_interest: int, _position: Vector3, _object: Object, _emitter: CharacterSense) -> void:
		interest = _interest
		position = _position
		emitter = _emitter
		object = _object
		time = 0.0
	
	func set_interest_level(new_interest: int) -> void:
		interest = new_interest
		time = 0.0

	func tick(delta: float, indirect_sensor: BTInterestMachine) -> bool:
		time += delta

		if time > indirect_sensor.attention_span:
			interest -= indirect_sensor.decay_rate * delta
		return interest <= 0
	
	func _to_string() -> String:
		return str({"interest": interest, "position": position, "object": object.name})


func set_event(interest: int, position: Vector3, object: Object, emitter: CharacterSense) -> void:
	if !events.has(object) or (events.has(object) and events[object].interest < ( interest * detection_threshold)):
		if interest > detection_threshold and (emitter is TouchSensor or emitter is VisualSensor) and object is Player:
			emit_signal("player_detected", object, position)
		else: emit_signal("indirect_event_detected")
	
	if events.has(object):
#		prints("Has object", events[object].interest, interest)
		
		if interest >= events[object].interest:
#			print("Overriding event")
			events[object].set_interest_level(interest)
			events[object].position = position
			events[object].emitter = emitter
	else: events[object] = Event.new(interest, position, object, emitter)


func remove_event(object: Object) -> void:
	if events.has(object): events.erase(object)


func _process(delta: float) -> void:
	for event in events.values(): if event.tick(delta, self):
		remove_event(event.object)


func sort_event_custom_sort(a: Event, b: Event) -> bool:
	return int(a.interest) > int(b.interest)


func get_most_interesting() -> Event:
	var sorted_events := events.values()
	if sorted_events.empty(): return null
	sorted_events.sort_custom(self, "sort_event_custom_sort")
	return sorted_events[0]


func _tick(state: CharacterState) -> int:
	var most_interesting := get_most_interesting()
	state.interest_machine = self
	
	if is_instance_valid(most_interesting):
		state.target_position = most_interesting.position
		state.target = most_interesting
#		prints("Set new position", state.target.position , state.target.interest, state.target.emitter.name, state.target.object.name)
		return BTResult.OK
	
	state.target = null
	return BTResult.FAILED
