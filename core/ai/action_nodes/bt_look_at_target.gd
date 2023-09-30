class_name BT_Look_At_Target
extends BT_Node


func tick(state : CharacterState) -> int:
	# This sets the target facing direction, and immediately exits.
	# Note that the character may not be facing in the given direction yet
	# When this node succeeds
	state.face_direction = state.target_position - state.character.global_transform.origin
	return Status.SUCCESS
