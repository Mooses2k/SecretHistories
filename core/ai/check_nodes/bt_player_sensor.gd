class_name BTPlayerSensor
extends BTNode

# What it says on the tin. Direct (sight or touch, typically) detection of the player character.


signal character_detected   # For signalling speech

export var sensor : NodePath
onready var _sensor : PlayerSensor = get_node(sensor) as PlayerSensor


func tick(state : CharacterState) -> int:
	var speech_chance = randf()
	if _sensor.is_player_detected():
		state.target_position = _sensor.get_measured_position()
		if (speech_chance > 0.99):
			emit_signal("character_detected")
		return Status.SUCCESS
	return Status.FAILURE
