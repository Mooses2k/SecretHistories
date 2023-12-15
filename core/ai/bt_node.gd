class_name BTNode extends Node


enum\
{
	OK,
	FAILED,
	BUSY,
	SKIP,
}


func tick(_state : CharacterState) -> int:
	return FAILED
