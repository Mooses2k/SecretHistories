class_name VisualFlame
extends MeshInstanceLayered

# This script serves the purpose of providing  more advanced features that 
# requires more than GLSL can offer, such as the top having a delay to follow 
# the bottom and randomizing the seed of the noise offset.


func _ready() -> void:
	randomize()
	set("material/0", get("material/0").duplicate())
	var material = get("material/0")
	material.set_shader_param("noise_seed", rand_range(0,1000))
