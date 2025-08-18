@tool
class_name CharacterSense extends Area3D


signal event(interest, position, object, emitter)


func tick(_character: HumanoidCharacter, _delta: float) -> int:
	return OK
