class_name BTIndirectSensor extends BTNode


export var attention_span := 5.0
export var decay_rate := 1.0


var events := {}


class Event:
	var position := Vector3.ZERO
	var object: Object
	var interest := 0.0
	
	var time := 0.0

	func _init(_interest: int, _position: Vector3, _object: Object) -> void:
		interest = _interest
		position = _position
		object = _object
	
	func set_interest_level(new_interest: int) -> void:
		interest = new_interest
		time = 0.0

	func tick(delta: float, indirect_sensor: BTIndirectSensor) -> bool:
		time += delta

		if time > indirect_sensor.attention_span:
			interest -= indirect_sensor.decay_rate * delta
		return interest <= 0


func set_event(interest: int, position: Vector3, object: Object) -> void:
	if events.has(object):
		events[object].set_interest_level(interest)
		events[object].position = position
	else: events[object] = Event.new(interest, position, object)


func remove_sensory_input(object: Object) -> void:
	if events.has(object): events.erase(object)
	

func _process(delta: float) -> void:
	for event in events.values():
		event.tick(delta)


func sort_event_custom_sort(a: Event, b: Event) -> bool:
	return int(a.interest) > int(b.interest)


func get_most_interesting() -> Event:
	var sorted_events := events.values()
	if sorted_events.empty(): return null
	sorted_events.sort_custom(self, "sort_event_custom_sort")
	return sorted_events[-1]
