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
## Deviations, recorded in docs/research/parity-missed-audit.md:
## restore targets the dev4 camera baseline (75, the player.tscn Camera3D
## default) instead of 3.x's exported normal_fov 70, so the un-zoomed view is
## unchanged; the spyglass leaving the inventory ends the zoom even mid-hold
## (3.x required the item again on release, so dropping it while zoomed left
## the camera stuck).
## The deferred 3.x zoom_camera_sens_mod half (player_camera.gd:24, applied
## at fps_control_mode.gd:90,92): while zoomed the mouse-look scale is 0.25
## through the player controller's camera_look_mod seam, restored to 1.0 on
## release. ADS is not part of this: fresh 3.x reads show no mouse-look
## scale on ADS, so while ADS owns the fov this controller stands down
## instead of lerping back and the look mod stays 1.0.
## Attached at runtime by Game.spawn_player under the player's main camera.

const SPYGLASS_ITEM : Resource = preload("res://resources/tiny_items/spyglass.tres")

const ZOOM_FOV : float = 30.0
const ZOOM_LERP_WEIGHT : float = 0.25
const RESTORE_LERP_WEIGHT : float = 0.1
const ZOOM_LOOK_MOD : float = 0.25

var main_camera : Camera3D
var inventory : Inventory
var player_controller : PlayerController

var _zooming : bool = false
var _look_mod_applied : bool = false
var _normal_fov : float = 75.0


## Wire the node references. Call after the node is in the tree.
func setup(camera : Camera3D, inv : Inventory, controller : PlayerController) -> void:
	main_camera = camera
	inventory = inv
	player_controller = controller
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
	_apply_look_mod()
	_apply_fov()


## The zoom owns the look seam on its edges only: 0.25 while held (3.x
## zoom_camera_sens_mod parity), back to 1.0 on release unless ADS took the
## seam meanwhile (it re-applies its own value every frame).
func _apply_look_mod() -> void:
	if player_controller == null:
		return
	if _zooming and not _look_mod_applied:
		player_controller.camera_look_mod = ZOOM_LOOK_MOD
		_look_mod_applied = true
	elif not _zooming and _look_mod_applied:
		_look_mod_applied = false
		if not player_controller.is_ads_active:
			player_controller.camera_look_mod = 1.0


func _apply_fov() -> void:
	if _zooming:
		main_camera.fov = lerpf(main_camera.fov, ZOOM_FOV, ZOOM_LERP_WEIGHT)
	elif player_controller != null and player_controller.is_ads_active:
		# ADS owns the fov while aimed; do not fight it with restore lerps.
		pass
	else:
		main_camera.fov = lerpf(main_camera.fov, _normal_fov, RESTORE_LERP_WEIGHT)


func _carries_spyglass() -> bool:
	return inventory.tiny_items.has(SPYGLASS_ITEM)
