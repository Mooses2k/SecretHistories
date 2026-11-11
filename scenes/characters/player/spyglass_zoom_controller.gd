class_name SpyglassZoomController
extends Node

## Spyglass hold-to-zoom (3.x parity). Holding the ablty|binocs_spyglass
## action while the player carries the spyglass tiny item lerps the main
## camera fov toward the 3.x zoom target and back on release.
## Parity spec: origin/main scenes/characters/player/player_controller.gd:841-848
## (input gate) and scenes/characters/player/player_camera.gd:42-49 (zoom
## application): zoom target fov 30, lerp weight 0.25 toward zoom while held,
## lerp weight 0.1 back toward normal when idle, no zoom tiers, one item and
## one action (the 3.x action name mentions binoculars, the gate checks only
## the spyglass tiny item).
## Deviations, recorded in docs/research/parity-remainder-audit.md:
## restore targets the dev4 camera baseline (75, the player.tscn Camera3D
## default) instead of 3.x's exported normal_fov 70, so the un-zoomed view is
## unchanged; the spyglass leaving the inventory ends the zoom even mid-hold
## (3.x required the item again on release, so dropping it while zoomed left
## the camera stuck); the 3.x zoom_camera_sens_mod (0.25x mouse look while
## zoomed, fps_control_mode.gd:90) is deferred because dev4 mouse look lives
## in the frozen player_controller input path.
## Attached at runtime by Game.spawn_player under the player's main camera.

const SPYGLASS_ITEM : Resource = preload("res://resources/tiny_items/spyglass.tres")

const ZOOM_FOV : float = 30.0
const ZOOM_LERP_WEIGHT : float = 0.25
const RESTORE_LERP_WEIGHT : float = 0.1

var main_camera : Camera3D
var inventory : Inventory

var _zooming : bool = false
var _normal_fov : float = 75.0


## Wire the node references. Call after the node is in the tree.
func setup(camera : Camera3D, inv : Inventory) -> void:
	main_camera = camera
	inventory = inv
	_normal_fov = camera.fov


func _physics_process(_delta : float) -> void:
	if main_camera == null or inventory == null:
		return
	if Input.is_action_just_pressed(&"ablty|binocs_spyglass") and _carries_spyglass():
		_zooming = true
	if Input.is_action_just_released(&"ablty|binocs_spyglass"):
		_zooming = false
	# The spyglass leaving the inventory ends the zoom even mid-hold.
	if _zooming and not _carries_spyglass():
		_zooming = false
	if _zooming:
		main_camera.fov = lerpf(main_camera.fov, ZOOM_FOV, ZOOM_LERP_WEIGHT)
	else:
		main_camera.fov = lerpf(main_camera.fov, _normal_fov, RESTORE_LERP_WEIGHT)


func _carries_spyglass() -> bool:
	return inventory.tiny_items.has(SPYGLASS_ITEM)
