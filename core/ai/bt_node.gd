class_name BTNode
extends Node


enum Status {
	SUCCESS,
	FAILURE,
	RUNNING,
	COUNT
}


func tick(state : CharacterState) -> int:
	return Status.FAILURE
