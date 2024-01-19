@tool 
class_name VisualFlame 
extends MeshInstanceLayered

# This script serves the purpose of providing more advanced features that 
# requires more than GLSL can offer, such as the top having a delay to follow 
# the bottom and randomizing the seed of the noise offset.
const FIRE = preload("res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/material/fire.material")

var material: Material = null


func _ready() -> void:
	randomize()
	material = get_surface_override_material(0)
	if not is_instance_valid(material):
		material = FIRE
	material = material.duplicate(); 
	material.set_shader_parameter("noise_seed", randf_range(0,1000))
	set_surface_override_material(0, material)


# Pauses the flame shader when parent Node paused
func _notification(what: int) -> void:
	pass
	# TODO: No equivalent in Godot 4, can be implemented as a global shader
	# uniform that is manually managed
	#if what == NOTIFICATION_PAUSED  : RenderingServer.set_shader_time_scale(0.0) # RenderingServer in Godot 4
	#if what == NOTIFICATION_UNPAUSED: RenderingServer.set_shader_time_scale(1.0)
