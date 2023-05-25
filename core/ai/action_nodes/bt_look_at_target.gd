class_name BT_Look_At_Target
extends BT_Node


func tick(state : CharacterState) -> int:
	state.face_direction = state.target_position - state.character.global_transform.origin
	return Status.SUCCESS
