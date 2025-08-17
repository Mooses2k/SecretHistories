extends PhysicalBoneSimulator3D

@onready var character := owner as HumanoidCharacter

func _on_state_physical_state_changed(new_physical_state: HumanoidCharacterState.PhysicalState) -> void:
	match new_physical_state:
		HumanoidCharacterState.PhysicalState.RAGDOLLED, HumanoidCharacterState.PhysicalState.DEAD:
			physical_bones_start_simulation()
			#active = true
			character.character_collision.disabled = true
			character.freeze = true
		_:
			physical_bones_stop_simulation()
			#active = false
			character.character_collision.disabled = false
			character.freeze = false
	pass # Replace with function body.

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if owner is not Player and event.is_pressed() and event.key_label == KEY_O:
			if owner.state.physical_state == HumanoidCharacterState.PhysicalState.RAGDOLLED:
				owner.state.physical_state = HumanoidCharacterState.PhysicalState.NORMAL
			else:
				owner.state.physical_state = HumanoidCharacterState.PhysicalState.RAGDOLLED

func _ready() -> void:
	for c in get_children():
		if c is PhysicalBone3D:
			c.add_collision_exception_with(character)
