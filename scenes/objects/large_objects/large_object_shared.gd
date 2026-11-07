class_name LargeObjectShared
extends RefCounted

## Body-agnostic state shared by large_object.gd (RigidBody3D) and
## static_large_object.gd (StaticBody3D). The impact audio manager wiring is
## rigid-only and lives in large_object.gd: static bodies have no
## _integrate_forces, and ImpactAudioManager requires a RigidBody3D parent.

var item_drop_sound : AudioStream
var noise_level : float = 0   # Noise detectable by characters; is a float for stamina -> noise conversion if nothing else
var item_max_noise_level : int = 0
# Loot scene paths placed by an embedded AnchorSpawner (sarcophagus/pedestal pattern)
var spawnable_items : PackedStringArray


## Method for the audio manager to set noise level
func set_noise_level(level: float) -> void:
	noise_level = level
