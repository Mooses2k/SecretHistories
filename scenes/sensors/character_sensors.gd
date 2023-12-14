class_name CharacterSensors extends Spatial


var _character: NodePath
var character: Character
var sensors: Array


func _ready() -> void:
	for child in get_children():
		if child is CharacterSense:
			sensors.append(child)


func _process(delta: float) -> void:
	for sensor in sensors: sensor.tick(character, delta)

