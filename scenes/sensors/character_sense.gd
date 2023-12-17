tool class_name CharacterSense extends Area

signal event(interest, position, object, emissor)

func tick(_character: Character, _delta: float) -> int:
	return OK