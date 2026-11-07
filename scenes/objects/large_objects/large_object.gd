class_name LargeObject
extends RigidBody3D

## Rigid large object: furniture, debris, and breakable statues that move.
## Noise and drop-sound state lives in LargeObjectShared; static-root
## scenery uses static_large_object.gd instead.

var _shared := LargeObjectShared.new()

var impact_audio_manager : ImpactAudioManager

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


## Accumulated break damage, exposed for tests and probes.
func get_break_accumulated_damage() -> float:
	return _shared.get_break_accumulated_damage()


func _enter_tree() -> void:
	# Create and configure the impact audio manager
	impact_audio_manager = ImpactAudioManager.new()
	add_child(impact_audio_manager)
	impact_audio_manager.configure_for_object_type("large_object")


func _ready() -> void:
	# Configure the audio manager with our sound and noise settings
	# Use call_deferred with a slight delay to ensure child classes have set their values first
	await get_tree().process_frame
	_configure_audio_manager()


func _configure_audio_manager() -> void:
	prints("LARGE OBJECT DEBUG - Configuring audio manager")
	prints("LARGE OBJECT DEBUG - impact_audio_manager:", impact_audio_manager)
	prints("LARGE OBJECT DEBUG - item_drop_sound:", item_drop_sound)
	prints("LARGE OBJECT DEBUG - item_max_noise_level:", item_max_noise_level)

	if impact_audio_manager and item_drop_sound:
		impact_audio_manager.drop_sound = item_drop_sound
		impact_audio_manager.max_noise_level = item_max_noise_level
		prints("LARGE OBJECT DEBUG - Audio manager configured successfully")
	else:
		prints("LARGE OBJECT DEBUG - Failed to configure audio manager!")


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Delegate impact detection to the audio manager
	if impact_audio_manager:
		impact_audio_manager.process_impact_detection(state)


## Method for the audio manager to set noise level
func set_noise_level(level: float) -> void:
	_shared.set_noise_level(level)
