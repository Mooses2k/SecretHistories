extends PhysicalBoneSimulator3D

@export_flags_3d_physics var collision_layer : int = 1
@export_flags_3d_physics var collision_mask : int = 1

var _bones : Array[PhysicalBone3D]

@onready var character := owner as HumanoidCharacter
@onready var physical_bone_def_spine: PhysicalBone3D = $"Physical Bone DEF-spine"

func _on_state_physical_state_changed(new_physical_state: HumanoidCharacterState.PhysicalState) -> void:
	if character.state.is_ragdolled():
		physical_bones_start_simulation()
		#active = true
		character.character_collision.disabled = true
		_enable_bone_collision()
		character.freeze = true
	else:
		physical_bones_stop_simulation()
		#active = false
		_disable_bone_collison()
		character.character_collision.disabled = false
		character.global_position = physical_bone_def_spine.global_position
		character.freeze = false
	pass # Replace with function body.
#
#func _input(event: InputEvent) -> void:
	#if event is InputEventKey:
		#if owner is not Player and event.is_pressed() and event.key_label == KEY_O:
			#if owner.state.physical_state == HumanoidCharacterState.PhysicalState.KNOCKED_OUT:
				#owner.state.physical_state = HumanoidCharacterState.PhysicalState.NORMAL
			#else:
				#owner.state.physical_state = HumanoidCharacterState.PhysicalState.KNOCKED_OUT

func _ready() -> void:
	for c in get_children():
		if c is PhysicalBone3D:
			c.add_collision_exception_with(character)
			_bones.push_back(c)
	_disable_bone_collison()

func _disable_bone_collison() -> void:
	for b in _bones:
		b.collision_layer = 0
		b.collision_mask = 0
	pass

func _enable_bone_collision() -> void:
	for b in _bones:
		b.collision_layer = collision_layer
		b.collision_mask = collision_mask
	pass
