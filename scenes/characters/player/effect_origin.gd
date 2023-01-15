tool
extends Position3D


export var material : ShaderMaterial;
export var uniform_name_transform : String = "EFFECT_TRANSFORM"
export var uniform_name_position : String = "EFFECT_ORIGIN"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_instance_valid(material):
		material.set_shader_param(uniform_name_transform, global_transform.affine_inverse())
		material.set_shader_param(uniform_name_position, global_translation)
