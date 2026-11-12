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
## Owner feature (2026-11-09, not 3.x parity: 3.x handle_binocs only flipped
## the camera state): raising the spyglass with a non-bulky mainhand item or
## gun first puts the item away through the inventory's own same-slot holster
## toggle (Inventory.set_mainhand_slot with the item's own slot), so the
## landed stow seams apply exactly as on a hotbar switch: a lit light goes
## out (owner ruling #644), a belt-capable lantern stows onto the belt hook
## still burning, and no equip coroutine is armed. On release the SAME item
## returns to the mainhand through the normal equip path with its landed
## 0.5 s draw. A bulky mainhand means B does nothing at all (the spyglass
## reads as offhand use then), and an active reload keeps its gun (the
## put-away must not preempt reload state). The spyglass itself is a tiny
## item and never routes through equip.
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

# The mainhand item put away for the hold: its hotbar slot and the node, so
# release can return the SAME item and skip the return when the slot was
# refilled, the selection moved, or a hand took something back mid-hold.
# A negative slot stores nothing.
var _holstered_slot : int = -1
var _holstered_item : EquipmentItem = null


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
		_raise_spyglass()
	if Input.is_action_just_released(&"ablty|binocs_spyglass"):
		_set_zooming(false)
		_restore_mainhand()
	# The spyglass leaving the inventory ends the zoom even mid-hold.
	if _zooming and not _carries_spyglass():
		_set_zooming(false)
	# Death ends the hold and cancels the return: the death cam owns the
	# camera and no item re-equips onto a corpse (the put-away stands).
	if GameManager.is_player_dead and (_zooming or _holstered_slot >= 0):
		_set_zooming(false)
		_holstered_slot = -1
		_holstered_item = null
	_apply_look_mod()
	_apply_fov()


## The raise: the owner rulings gate it. A bulky mainhand means nothing at
## all happens (no put-away, no zoom), an active reload keeps its gun, a
## dead player never raises. Otherwise the mainhand item, if any, is put
## away first and the zoom begins.
func _raise_spyglass() -> void:
	if GameManager.is_player_dead:
		return
	if inventory.bulky_equipment != null:
		return
	if player_controller != null and player_controller.state != null \
			and player_controller.state.is_reloading:
		return
	_holster_mainhand()
	_set_zooming(true)


## The put-away: the same-slot holster toggle the hotbar key uses
## (Inventory.set_mainhand_slot with the equipped item's own slot). The
## precondition (mainhand item sitting in its own slot) makes the toggle a
## holster, never an equip. The put-away is synchronous: the toggle only
## extinguishes, belt-stows and unequips, so the zoom begins the same frame.
func _holster_mainhand() -> void:
	var item : EquipmentItem = inventory.get_mainhand_item()
	if item == null:
		return
	var slot : int = inventory.current_mainhand_slot
	if inventory.hotbar[slot] != item:
		return
	_holstered_slot = slot
	_holstered_item = item
	inventory.set_mainhand_slot(slot)


## The return: the same-slot toggle again, now arming the inventory's normal
## equip coroutine with its landed 0.5 s draw. Skipped when the stored item
## left its slot (dropped or stolen mid-hold), when a hotbar switch moved
## the selection away, or when something already took the mainhand, so
## nothing is ever restored twice.
func _restore_mainhand() -> void:
	if _holstered_slot < 0:
		return
	var slot : int = _holstered_slot
	var item : EquipmentItem = _holstered_item
	_holstered_slot = -1
	_holstered_item = null
	if inventory.current_mainhand_slot != slot:
		return
	if inventory.get_mainhand_item() != null:
		return
	if inventory.hotbar[slot] != item:
		return
	inventory.set_mainhand_slot(slot)


func _set_zooming(value : bool) -> void:
	if _zooming == value:
		return
	_zooming = value
	# Report the hold into the landed arbitration seam so the player
	# controller's ADS fov application and restore stand down while the
	# zoom owns the camera.
	if player_controller != null:
		player_controller.set_spyglass_zoom_active(value)


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
