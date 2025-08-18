@tool
extends Marker3D


@export var material : ShaderMaterial
@export var uniform_name_transform : String = "EFFECT_TRANSFORM"
@export var uniform_name_position : String = "EFFECT_ORIGIN"


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_instance_valid(material):
		material.set_shader_parameter(uniform_name_transform, global_transform.affine_inverse())
		material.set_shader_parameter(uniform_name_position, global_position)
