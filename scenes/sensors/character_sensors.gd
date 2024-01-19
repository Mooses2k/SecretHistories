class_name CharacterSensors extends Node3D


var _character: NodePath
var character: Character
var sensors: Array


func _ready() -> void:
	for child in get_children():
		if child is CharacterSense:
			sensors.append(child)


func _process(delta: float) -> void:
	if Engine.get_process_frames() % 2 != 0: return
	for sensor in sensors: sensor.tick(character, delta)
