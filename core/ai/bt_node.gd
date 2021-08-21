class_name BT_Node
extends Node

enum Status {
	SUCCESS,
	FAILURE,
	RUNNING,
	COUNT
}

func tick(state : CharacterState) -> int:
	return Status.FAILURE
