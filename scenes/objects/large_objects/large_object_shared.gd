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

# Break behavior: damage accumulates per hit until the threshold is crossed,
# then the host swaps into its broken variant scene. Shared here so rigid and
# static hosts carry the identical swap logic; door breaking stays separate
# (base_kinematic_door.gd is door-specific).
var break_damage_threshold : float = 100.0
var break_noise_level : float = 10.0   # Loud: breaking a statue is heard room-wide
var broken_scene_override : PackedScene
var _break_accumulated_damage : float = 0.0
var _broken_scene : PackedScene
var _broken_scene_resolved : bool = false


## Method for the audio manager to set noise level
func set_noise_level(level: float) -> void:
	noise_level = level


## Record one hit of damage on the host. Breakable hosts swap into their
## broken variant when the accumulated damage crosses the threshold;
## unbreakable hosts (no resolvable broken variant) ignore all damage.
func accumulate_break_damage(amount : float, host : Node) -> void:
	if not is_breakable(host):
		return
	_break_accumulated_damage += amount
	if _break_accumulated_damage >= break_damage_threshold:
		_swap_into_broken(host)


## A host is breakable when a broken variant scene resolves for it.
func is_breakable(host : Node) -> bool:
	if not _broken_scene_resolved:
		_broken_scene_resolved = true
		_broken_scene = _resolve_broken_scene(host)
	return _broken_scene != null


## Accumulated damage, exposed for tests and probes.
func get_break_accumulated_damage() -> float:
	return _break_accumulated_damage


## Resolve the broken variant: the override wins, otherwise the variant is
## derived from the intact scene path by inserting "_broken" before ".tscn"
## (statue_gargoyle_2.tscn -> statue_gargoyle_2_broken.tscn convention).
func _resolve_broken_scene(host : Node) -> PackedScene:
	if broken_scene_override:
		return broken_scene_override
	var scene_path : String = host.scene_file_path
	if scene_path.is_empty() or not scene_path.ends_with(".tscn"):
		return null
	var broken_path := scene_path.insert(scene_path.length() - 5, "_broken")
	if ResourceLoader.exists(broken_path):
		return load(broken_path)
	return null


## Instance the broken scene as a sibling of the host at the host's transform,
## emit a large noise on the shared noise surface, then free the intact host.
func _swap_into_broken(host : Node) -> void:
	var parent := host.get_parent()
	if parent == null or not host.is_inside_tree():
		return
	var broken := _broken_scene.instantiate()
	# Compute the local transform before add_child so the deferred sibling
	# lands exactly where the intact statue stood.
	if parent is Node3D and host is Node3D:
		broken.transform = (parent as Node3D).global_transform.affine_inverse() * (host as Node3D).global_transform
	parent.add_child.call_deferred(broken)
	host.set_noise_level(break_noise_level)
	host.queue_free()
