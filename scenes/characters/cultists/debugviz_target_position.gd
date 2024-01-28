extends MeshInstance3D


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var state = owner.character_state as CharacterState
	if is_instance_valid(state):
#		var path = state.path
#		if not path.empty():
#			var pos = state.path[0]
#			global_translation = pos
		global_position = state.target_position
