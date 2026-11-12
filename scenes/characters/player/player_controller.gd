extends Node
class_name PlayerController


const CAMERA_STANDING_HEIGHT = 1.6
const CAMERA_CROUCHING_HEIGHT = 1.1

# Constants for auto-switch weapon setting
const SETTING_AUTO_SWITCH_WEAPON: String = "Auto-switch weapons on throw"

# 3.x ADS parity (player_old/player_anims.gd:148-212): per-size camera fov
# targets and the per-frame lerp weights the 3.x hold path applied every
# frame. Small items (revolvers) aim at 65, medium guns (rifles, shotguns)
# at 60; the release lerps back at the 3.x end_ads weight. The restore
# baseline is the dev4 camera default (75), not 3.x's normal_fov 70, the
# same documented deviation the spyglass zoom lane recorded.
const ADS_FOV_SMALL : float = 65.0
const ADS_FOV_MEDIUM : float = 60.0
const ADS_FOV_LERP_SMALL : float = 0.1
const ADS_FOV_LERP_MEDIUM : float = 0.04
const ADS_FOV_RESTORE_LERP : float = 0.1
const ADS_BLEND_L : String = "parameters/ads_l/blend_amount"
const ADS_BLEND_R : String = "parameters/ads_r/blend_amount"
const ADS_BLEND_RATE_SMALL : float = 0.1
const ADS_BLEND_RATE_MEDIUM : float = 0.05
const ADS_RESTORE_TWEEN_TIME : float = 0.1

@onready var state: HumanoidCharacterState = $"../State"
@onready var input: HumanoidCharacterInput = $"../Input"
@onready var main_camera: Camera3D = $"../ModelRoot/MainCamera"
@onready var debug_light: SpotLight3D = $"../ModelRoot/MainCamera/DebugLight"

var screen_filter_controller : ScreenFilterController

var camera_pitch : float = 0.0
var drag_speed_modifier : float = 1.0

var moved_since_sprint : bool = false
var dodge_performed : bool = false
var was_sprinting : bool = false  # Track previous sprint state to detect sprint end
var sprint_end_time : float = 0.0  # Time when sprint ended

# Mouse-look scale seam (3.x fps_control_mode.gd:90,92 pattern): the mouse
# motion path multiplies the sensitivity by this factor. ADS scales it by the
# live-read Ironsight Aim Sensitivity setting (owner ruling 2026-11-09: these
# are ironsight aims, so the default is a mild 0.8; 1.0 restores the exact
# 3.x behavior where ADS applied no look scale). The spyglass zoom sets 0.25
# (3.x player_camera.gd zoom_camera_sens_mod parity) and restores 1.0 when
# it releases. The seam floor is 0.05 so no consumer can freeze the look.
var camera_look_mod : float = 1.0

var is_ads_active : bool = false
var _spyglass_zoom_active : bool = false
var _ads_fov_restoring : bool = false
var _ads_fov_resting_baseline : float = 75.0
var _ads_hold_tween : Tween
var _ads_blend_tween : Tween

@onready var character_animation_tree : AnimationTree = get_node_or_null("../CharacterAnimationTree")


func _ready() -> void:
	# The 3.x L screen-filter cycle (ending in the camera debug light), run
	# by the shared controller on the Game's CompositorEffect pipeline.
	screen_filter_controller = ScreenFilterController.new()
	add_child(screen_filter_controller)
	screen_filter_controller.setup(debug_light)
	_ads_fov_resting_baseline = main_camera.fov


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var sens = InputSettings.setting_mouse_sensitivity * 0.001 * camera_look_mod
		camera_pitch -= sens*event.relative.y
		camera_pitch = clamp(camera_pitch, - PI * 0.5, PI * 0.5)
		state.facing = state.facing.rotated(Vector3.UP, -sens*event.relative.x)


func _process(_delta : float) -> void:
	main_camera.rotation.x = camera_pitch
	main_camera.position.y = lerp(CAMERA_STANDING_HEIGHT, CAMERA_CROUCHING_HEIGHT, state.current_crouch_ratio)


func _physics_process(delta: float) -> void:
	# Handle noclip toggle
	if Input.is_action_just_pressed(&"debug_noclip"):
		owner.toggle_noclip()

	# Screen filter cycle: L advances the 3.x filter order and the lowest
	# floor forces the reduce color filter once (see ScreenFilterController).
	if screen_filter_controller != null:
		screen_filter_controller.handle_screen_filters()

	var input_vector_2d := Input.get_vector(&"movement|move_left", &"movement|move_right", &"movement|move_up", &"movement|move_down")
	var input_vector = Vector3(input_vector_2d.x, 0.0, input_vector_2d.y)

	# Apply drag speed modifier to movement
	input.movement_vector = state.facing * input_vector * drag_speed_modifier

	input.sprint = Input.is_action_pressed(&"player|sprint")
	var is_sprinting := input.sprint and not input.movement_vector.is_zero_approx()

	# In noclip mode, use continuous input for jump; otherwise use just_pressed for normal jumping
	if state.noclip_enabled:
		input.jump = Input.is_action_pressed(&"player|jump")
		input.crouch = Input.is_action_pressed(&"player|crouch")
	else:
		input.jump = Input.is_action_just_pressed(&"player|jump")
		input.crouch = Input.is_action_pressed(&"player|crouch") and not is_sprinting  # can't crouch if sprinting

	# Reset timer whenever forward + sprint is pressed to prevent false positive dodges
	var forward_pressed = input_vector_2d.y < 0  # negative y means forward movement
	if input.sprint and forward_pressed:
		sprint_end_time = 0.0
	else:
		sprint_end_time += delta

	was_sprinting = is_sprinting

	# Dodge detection - prevent dodge for brief period after sprint ends
	var sprint_recently_ended = sprint_end_time < 0.5
	if input.sprint and not dodge_performed and not sprint_recently_ended and state.time_since_dodge >= (owner as HumanoidCharacter).parameters.dodge_cooldown:
		# Check for left, right, or down movement (not forward)
		var movement_direction = input.movement_vector.normalized()
		var forward_direction = -state.facing.z
		var dot_product = movement_direction.dot(forward_direction)

		# If moving sideways or backward (not forward)
		if not is_equal_approx(dot_product, 1.0) and not input.movement_vector.is_zero_approx():
			# Check if moving left, right, or down specifically AND move_up is NOT pressed
			# input_vector_2d.y < 0 means move_up is pressed
			if (input_vector_2d.x != 0 or input_vector_2d.y > 0) and input_vector_2d.y >= 0:
				owner.dodge()
				dodge_performed = true

	# If pressed sprint without moving, kick
	if Input.is_action_just_released(&"player|sprint") and not moved_since_sprint:
		kick()

	# moved is true if sprinting and either already moved or is moving, false otherwise
	moved_since_sprint = input.sprint and (moved_since_sprint or is_sprinting)

	# ADS sustain (3.x player_controller.gd:664-688): while aimed, sprinting,
	# reloading, a missing gun, or death each end the aim. The camera fov
	# follows the 3.x per-size lerp while aimed and eases back to the dev4
	# camera baseline afterwards.
	if is_ads_active:
		var ads_gun := _mainhand_gun()
		if GameManager.is_player_dead or input.sprint or state.is_reloading or ads_gun == null:
			_end_ads()
		else:
			_apply_ads_look_mod()
			if not _spyglass_zoom_active:
				var ads_small := ads_gun.item_size == GlobalConsts.ItemSize.SIZE_SMALL
				var ads_target := ADS_FOV_SMALL if ads_small else ADS_FOV_MEDIUM
				var ads_weight := ADS_FOV_LERP_SMALL if ads_small else ADS_FOV_LERP_MEDIUM
				main_camera.fov = lerpf(main_camera.fov, ads_target, ads_weight)
	elif _ads_fov_restoring and not _spyglass_zoom_active and not GameManager.is_player_dead:
		main_camera.fov = lerpf(main_camera.fov, _ads_fov_baseline(), ADS_FOV_RESTORE_LERP)
		if absf(main_camera.fov - _ads_fov_baseline()) < 0.05:
			_ads_fov_restoring = false

	# 3.x ability release chain (origin/main player_controller.gd:611-617):
	# releasing F or N uses the belt item first, then the offhand item, then
	# the mainhand item. A belt-stowed lantern toggles its light here (with
	# the belt-clip hood sounds the lantern script plays while is_in_belt);
	# a held item gets its primary use, for lights the same on/off toggle.
	if Input.is_action_just_released(&"ablty|nightvision_darksight"):
		var inv : Inventory = (owner as HumanoidCharacter).inventory
		var belt_item : EquipmentItem = inv.belt_item as EquipmentItem
		var offhand_item : EquipmentItem = inv.get_offhand_item()
		var mainhand_item : EquipmentItem = inv.get_mainhand_item()
		if belt_item != null:
			belt_item.use_primary()
		elif offhand_item != null:
			offhand_item.use_primary()
		elif mainhand_item != null:
			mainhand_item.use_primary()


func set_drag_speed_modifier(modifier: float) -> void:
	drag_speed_modifier = max(modifier, 0.1)  # Ensure minimum 10% speed

	# Reset dodge_performed when sprint is released
	if not input.sprint:
		dodge_performed = false


## ADS entry point, called by the interact controller on the RMB hold on
## empty air and on the separately bound ads action (5 call sites). Ported
## from 3.x player_controller.gd:664-706 with its hold/toggle split:
## GameSettings.ads_hold_enabled true means hold (engage on press, release
## on release); false means toggle (a press flips the state, a release is
## inert). Gates follow the 3.x conditions: a GunItem in the mainhand, not
## sprinting, not reloading; sprint, reload, gun loss, and death end the
## aim in the _physics_process sustain block.
func set_ads(value : bool) -> void:
	if GameManager.is_player_dead:
		return
	if GameSettings.ads_hold_enabled:
		if value:
			_start_ads()
		else:
			_end_ads()
	else:
		if not value:
			return
		if is_ads_active:
			_end_ads()
		else:
			_start_ads()


## Spyglass zoom arbitration: the zoom controller reports its hold so ADS
## fov application stands down while the spyglass owns the camera.
func set_spyglass_zoom_active(active : bool) -> void:
	_spyglass_zoom_active = active


func _mainhand_gun() -> GunItem:
	var item : EquipmentItem = (owner as HumanoidCharacter).inventory.get_mainhand_item()
	if item is GunItem and is_instance_valid(item):
		return item
	return null


func _start_ads() -> void:
	var gun := _mainhand_gun()
	if gun == null:
		return
	if input.sprint or state.is_reloading:
		return
	is_ads_active = true
	_ads_fov_restoring = false
	_apply_ads_look_mod()
	_apply_ads_hold(gun)
	_apply_ads_blend(true, gun.item_size == GlobalConsts.ItemSize.SIZE_SMALL)


func _end_ads() -> void:
	if not is_ads_active:
		return
	is_ads_active = false
	_ads_fov_restoring = true
	_apply_ads_look_mod()
	var gun := _mainhand_gun()
	if gun != null and is_instance_valid(gun.hold_position):
		_tween_ads_hold(gun, gun.ads_reset_position, gun.ads_reset_rotation, ADS_RESTORE_TWEEN_TIME)
	_apply_ads_blend(false, gun != null and gun.item_size == GlobalConsts.ItemSize.SIZE_SMALL)


## 3.x player_anims.gd:151-160: the hold node snaps (a 0.0-duration tween)
## to the gun's authored ads_hold_rotation / ads_hold_position and eases
## back to the gun's ready-time reset values over 0.1 (player_anims.gd:184-192).
func _apply_ads_hold(gun : GunItem) -> void:
	if is_instance_valid(gun.hold_position):
		_tween_ads_hold(gun, gun.ads_hold_position, gun.ads_hold_rotation, 0.0)


func _tween_ads_hold(gun : GunItem, target_position : Vector3, target_rotation : Vector3, duration : float) -> void:
	if _ads_hold_tween != null and _ads_hold_tween.is_valid():
		_ads_hold_tween.kill()
	var hold := gun.hold_position as Node3D
	_ads_hold_tween = create_tween().set_parallel(true)
	_ads_hold_tween.tween_property(hold, "rotation_degrees", target_rotation, duration)
	_ads_hold_tween.tween_property(hold, "position", target_position, duration)


## 3.x player_anims.gd:161-176 blended parameters/SmallAds, MediumAds or
## ShotgunAds toward 1.0 (0.1 small, 0.05 medium/shotgun) and back on
## release. Dev4's humanoid tree (humanoid_character_base.tscn:3897-3900)
## carries no per-size ADS blends: it has a single ads_idle pose behind the
## ads_l / ads_r Blend2 nodes, so both are written with the 3.x rate for the
## current gun size. The per-size visual blends are asset-blocked.
func _apply_ads_blend(engage : bool, small_gun : bool) -> void:
	if character_animation_tree == null:
		return
	var target := 1.0 if engage else 0.0
	var rate := ADS_BLEND_RATE_SMALL if small_gun else ADS_BLEND_RATE_MEDIUM
	var from := float(character_animation_tree.get(ADS_BLEND_L))
	if _ads_blend_tween != null and _ads_blend_tween.is_valid():
		_ads_blend_tween.kill()
	_ads_blend_tween = create_tween()
	_ads_blend_tween.tween_method(_set_ads_blend_value, from, target, rate)


func _set_ads_blend_value(value : float) -> void:
	if character_animation_tree == null:
		return
	character_animation_tree.set(ADS_BLEND_L, value)
	character_animation_tree.set(ADS_BLEND_R, value)


func _ads_fov_baseline() -> float:
	return _ads_fov_resting_baseline


## The look seam value while aimed: the live-read ironsight sensitivity
## setting, clamped, so a settings change applies without a restart. While
## the spyglass zoom is active it owns the seam; ADS never touches it then.
func _apply_ads_look_mod() -> void:
	if _spyglass_zoom_active:
		return
	camera_look_mod = GameSettings.ads_look_scale() if is_ads_active else 1.0


func throw_object(object : RigidBody3D):
	print("throwing item")
	var inv : Inventory = (owner as HumanoidCharacter).inventory

	# Check if the thrown object is from mainhand or offhand (hotbar)
	var is_mainhand = object == inv.get_mainhand_item()
	var is_offhand = object == inv.get_offhand_item()
	var thrown_from_hotbar = is_mainhand or is_offhand

	# Store the type of item being thrown for same-type search
	var thrown_item_type = null
	if object is MeleeItem:
		thrown_item_type = object.get_script()  # Get the script type for comparison

	# Determine which slot was thrown from. The dropped node is what actually
	# left the inventory (T9): with units remaining in a record-backed stack
	# the representative stays and a fresh materialized node is the thrown
	# one; a null dropped node means nothing left the inventory.
	var thrown_slot = -1
	var thrown : RigidBody3D = object
	if is_mainhand:
		var dropped = inv.drop_mainhand_item()
		if dropped == null:
			return
		thrown = dropped
		thrown_slot = inv.current_mainhand_slot
	elif is_offhand:
		var dropped = inv.drop_offhand_item()
		if dropped == null:
			return
		thrown = dropped
		thrown_slot = inv.current_offhand_slot

	var impulse := 100.0
	if (thrown is PickableItem) and thrown.item_size == GlobalConsts.ItemSize.SIZE_SMALL:
		impulse = 50.0 * thrown.mass
	var impulse_vector := - main_camera.global_basis.z * impulse
	# Thrown-item audio rule: remember the thrower so the spin loop ignores
	# release-time contact with the hand and stops on the first real impact.
	thrown.set_meta("thrown_by", owner)
	thrown.apply_central_impulse(impulse_vector)
	if thrown is PickableItem:
		thrown.impact_damage_cooldown[owner] = PickableItem.IMPACT_DAMAGE_REPEAT_COOLDOWN
		thrown.set_item_state(GlobalConsts.ItemState.DROPPED)
		if thrown is EquipmentItem:
			thrown.apply_throw_logic(impulse_vector)

	thrown.add_collision_exception_with(owner)
	if thrown.has_method(&"play_throw_sound"):
		thrown.play_throw_sound()

	# Auto weapon switching logic (only for hotbar throws, not grabbed items)
	if thrown_from_hotbar and GameSettings.get_auto_switch_weapon() != 2 and thrown is MeleeItem:  # 2 = "None"
		_auto_switch_weapon(inv, thrown_item_type, is_mainhand, is_offhand, thrown_slot, thrown)


# Add the auto switch weapon helper function
func _auto_switch_weapon(inv: Inventory, thrown_item_type, is_mainhand: bool, is_offhand: bool, thrown_slot: int, thrown_item):
	var auto_switch_mode = GameSettings.get_auto_switch_weapon()  # 0 = "Next same type then all", 1 = "Next same type only"

	# First check if the thrown item came from a surviving stack record (T9).
	# The thrown node carries the record id, and the record is the count
	# truth. The old reference-equality resource match never fired across
	# local_to_scene resource copies anyway.
	if thrown_item is EquipmentItem and thrown_item.stack_record_id >= 0:
		var stack_record = inv.get_stack_record(thrown_item.stack_record_id)
		if stack_record != null and stack_record.count > 0:
			for i in range(inv.hotbar.size()):
				var hotbar_item = inv.hotbar[i]
				if hotbar_item != null and hotbar_item.stack_record_id == stack_record.id:
					if is_mainhand:
						inv.current_mainhand_slot = i
						inv.equip_mainhand_item()
					elif is_offhand:
						inv.current_offhand_slot = i
						inv.equip_offhand_item()
					return

	# Variables to store found items for each priority level
	var same_type_item = null
	var same_type_slot = -1
	var small_item = null
	var small_slot = -1
	var medium_item = null
	var medium_slot = -1

	# Search through hotbar from lowest to highest (0 to size-1)
	# This ensures we follow the "lowest to highest" requirement

	# Safety check: Ensure hotbar is valid
	if inv.hotbar == null:
		print("[ERROR] _auto_switch_weapon: hotbar is null!")
		return
	if inv.hotbar.size() == 0:
		print("[ERROR] _auto_switch_weapon: hotbar is empty!")
		return

	# First priority: Check for same type items across all slots
	for i in range(inv.hotbar.size()):
		# Skip the slot that just had an item thrown
		if i == thrown_slot:
			continue

		# Safety check: Ensure index is valid
		if i < 0 or i >= inv.hotbar.size():
			print("[ERROR] _auto_switch_weapon: Invalid index ", i, " for hotbar size ", inv.hotbar.size())
			continue

		var item = inv.hotbar[i]
		if item == null:
			continue

		# Check if this is a melee item of the same type
		if item is MeleeItem and thrown_item_type != null and item.get_script() == thrown_item_type:
			same_type_item = item
			same_type_slot = i
			# If we only want same type, we can break early
			if auto_switch_mode == 1:  # "Next same type only"
				break

	# If we found a same type item and we're in "same type only" mode, equip it and return
	if same_type_item != null and auto_switch_mode == 1:
		if is_mainhand:
			inv.current_mainhand_slot = same_type_slot
			inv.equip_mainhand_item()
		elif is_offhand:
			inv.current_offhand_slot = same_type_slot
			inv.equip_offhand_item()
		return

	# Second priority: Check for SIZE_SMALL MeleeItems (only if we're not in "same type only" mode)
	if auto_switch_mode == 0:  # "Next same type then all"
		for i in range(inv.hotbar.size()):
			# Skip the slot that just had an item thrown
			if i == thrown_slot:
				continue

			# Safety check: Ensure index is valid
			if i < 0 or i >= inv.hotbar.size():
				print("[ERROR] _auto_switch_weapon: SIZE_SMALL search - Invalid index ", i, " for hotbar size ", inv.hotbar.size())
				continue

			var item = inv.hotbar[i]
			if item == null:
				continue

			# Check if this is a SIZE_SMALL MeleeItem
			if item is MeleeItem and item.item_size == GlobalConsts.ItemSize.SIZE_SMALL:
				small_item = item
				small_slot = i
				break  # Take the first one found (lowest slot)

	# Third priority: Check for SIZE_MEDIUM MeleeItems (only if we're not in "same type only" mode)
	if auto_switch_mode == 0 and small_item == null:  # Only check if we haven't found a small item
		for i in range(inv.hotbar.size()):
			# Skip the slot that just had an item thrown
			if i == thrown_slot:
				continue

			# Safety check: Ensure index is valid
			if i < 0 or i >= inv.hotbar.size():
				print("[ERROR] _auto_switch_weapon: SIZE_MEDIUM search - Invalid index ", i, " for hotbar size ", inv.hotbar.size())
				continue

			var item = inv.hotbar[i]
			if item == null:
				continue

			# Check if this is a SIZE_MEDIUM MeleeItem
			if item is MeleeItem and item.item_size == GlobalConsts.ItemSize.SIZE_MEDIUM:
				medium_item = item
				medium_slot = i
				break  # Take the first one found (lowest slot)

	# Equip the appropriate item based on priority and settings
	var item_to_equip = null
	var slot_to_equip = -1

	if same_type_item != null:
		# Found same type item
		item_to_equip = same_type_item
		slot_to_equip = same_type_slot
	elif auto_switch_mode == 0:  # "Next same type then all"
		# Look for SIZE_SMALL first, then SIZE_MEDIUM
		if small_item != null:
			item_to_equip = small_item
			slot_to_equip = small_slot
		elif medium_item != null:
			item_to_equip = medium_item
			slot_to_equip = medium_slot

	# Equip the found item to the appropriate hand
	if item_to_equip != null and slot_to_equip != -1:
		if is_mainhand:
			inv.current_mainhand_slot = slot_to_equip
			inv.equip_mainhand_item()
		elif is_offhand:
			inv.current_offhand_slot = slot_to_equip
			inv.equip_offhand_item()


func place_object(object : RigidBody3D, at : Transform3D):
	var inv : Inventory = (owner as HumanoidCharacter).inventory
	if object == inv.get_mainhand_item():
		inv.drop_mainhand_item()
	elif object == inv.get_offhand_item():
		inv.drop_offhand_item()
	object.global_transform = at
	object.linear_velocity = Vector3.ZERO
	object.angular_velocity = Vector3.ZERO
	pass


func kick():
	owner.kick()
