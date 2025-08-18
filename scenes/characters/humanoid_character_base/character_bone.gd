@tool
extends PhysicalBone3D

const CharacterBone = preload("res://scenes/characters/humanoid_character_base/character_bone.gd")

@export var collision_exceptions : Array[CharacterBone]
@onready var hurtbox: Hurtbox = $Hurtbox

func _ready() -> void:
	if Engine.is_editor_hint(): return
	for bone in collision_exceptions:
		add_collision_exception_with(bone)
	for c in get_children():
		if c is CollisionShape3D:
			hurtbox.add_child(c.duplicate(0))
	#body_offset = Transform3D.IDENTITY

var _body_offset : Transform3D

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EDITOR_PRE_SAVE:
			#print(name, " pre: ", body_offset.origin)
			_body_offset = body_offset
		NOTIFICATION_EDITOR_POST_SAVE:
			body_offset = _body_offset
			#print(name," post: ", body_offset.origin)
