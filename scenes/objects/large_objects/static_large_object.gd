class_name StaticLargeObject
extends StaticBody3D

## Static-root large object: statues and immovable scenery. Carries the same
## noise and drop-sound surface as LargeObject without rigid mechanics: a
## static body has no _integrate_forces, and ImpactAudioManager requires a
## RigidBody3D parent, so impact audio stays rigid-only.

var _shared := LargeObjectShared.new()

var item_drop_sound : AudioStream:
	get:
		return _shared.item_drop_sound
	set(value):
		_shared.item_drop_sound = value

var noise_level : float:
	get:
		return _shared.noise_level
	set(value):
		_shared.noise_level = value

var item_max_noise_level : int:
	get:
		return _shared.item_max_noise_level
	set(value):
		_shared.item_max_noise_level = value

# Loot scene paths placed by an embedded AnchorSpawner (sarcophagus/pedestal pattern)
var spawnable_items : PackedStringArray:
	get:
		return _shared.spawnable_items
	set(value):
		_shared.spawnable_items = value

@export var break_damage_threshold : float = 100.0:
	get:
		return _shared.break_damage_threshold
	set(value):
		_shared.break_damage_threshold = value

@export var broken_scene_override : PackedScene:
	get:
		return _shared.broken_scene_override
	set(value):
		_shared.broken_scene_override = value


func accumulate_break_damage(amount : float) -> void:
	_shared.accumulate_break_damage(amount, self)


func is_breakable() -> bool:
	return _shared.is_breakable(self)


## Method for the audio manager to set noise level
func set_noise_level(level: float) -> void:
	_shared.set_noise_level(level)
