@tool
class_name MeshInstanceLayered
extends MeshInstance3D


@onready var parent = get_owner()


# Tracking the object's state in order to prevent clipping into walls when equipped
func _process(delta):
	if parent.get_parent().owner != null:
		if parent.get_parent().owner.name == "Player":
		#	if parent.mode == parent.equipped_mode:
				layers = 2
				cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
				layers = 1
				cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON   # TODO: There may be a bug here for lit light-sources when thrown, as those would have cast_shadow = false
			
	else:
		layers = 1
