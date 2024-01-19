extends ImmediateMesh


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	clear()
	var state = owner.character_state as CharacterState
	if is_instance_valid(state):
		var path = state.path
		if not path.is_empty():
			begin(Mesh.PRIMITIVE_LINE_STRIP)
			set_color(Color.WHITE)
			add_vertex(owner.global_position)
			for v in path:
				add_vertex(v)
			end()
