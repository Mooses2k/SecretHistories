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
		elif parent.get("is_lit") == true:
				layers = 1
				# Lit light source sitting in the level: its own meshes must
				# not shadow its own light (dark bands on the candle body and
				# an opaque flame-quad shadow at the light origin). The light
				# keeps shadow_enabled, so walls still occlude it.
				cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
				layers = 1
				cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			
	else:
		layers = 1
