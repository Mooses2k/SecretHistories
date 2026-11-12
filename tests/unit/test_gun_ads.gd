# Gun ADS port tests (M2): the 3.x ADS restoration on dev4. Pinned here:
# the per-size camera fov targets (small 65, medium 60, 3.x
# player_anims.gd:165,177) and their lerp behavior, the fov restore toward
# the dev4 camera baseline on release (3.x end_ads rate), the hold node
# consuming the gun's authored ads_hold_position / ads_hold_rotation exports
# and easing back to the ready-time reset values (player_anims.gd:151-192),
# the anim tree ads_l / ads_r blend driven to 1.0 and back (dev4 tree
# carries a single ads_idle pose behind those Blend2 nodes; the 3.x per-size
# SmallAds / MediumAds / ShotgunAds blends are asset-blocked on dev4), the
# hold/toggle split through GameSettings.ads_hold_enabled (3.x
# player_controller.gd:664-706), the gates (no gun, non-gun mainhand,
# sprinting, reloading, dead player), and the mouse-look seam: ADS applies
# the live-read Ironsight Aim Sensitivity setting (owner ruling
# 2026-11-09: mild ironsight default 0.8, 1.0 equals 3.x exactly, clamped
# floor 0.05) and the spyglass zoom holds 0.25 (3.x zoom_camera_sens_mod
# parity) while it owns the fov against ADS restore fights.
extends GutTest

const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const WEBLEY_SCENE := "res://scenes/objects/pickable_items/equipment/ranged/webley_revolver/webley.tscn"
const MARTINI_SCENE := "res://scenes/objects/pickable_items/equipment/ranged/martini_henry_rifle/martini_henry_rifle.tscn"
const LANTERN_SCENE := "res://scenes/objects/pickable_items/equipment/tool/light-sources/candle_lantern/candle_lantern.tscn"
const SPYGLASS_RESOURCE := "res://resources/tiny_items/spyglass.tres"
const ZOOM_CONTROLLER_SCRIPT := "res://scenes/characters/player/spyglass_zoom_controller.gd"

const CAMERA_BASELINE_FOV : float = 75.0
const SETTLE_FRAMES : int = 60

var _world : Node3D
var _game : Game
var _ui : GameUI
var _hud : HUD
var _saved_game : Game
var _saved_ads_hold : bool
var _saved_dead : bool


func before_each() -> void:
	# Headless stub set that keeps the real per-frame handlers error-free
	# (interact_controller needs ui_root.hud_root). Same pattern as the hold
	# position tests.
	_saved_game = GameManager.game
	_world = Node3D.new()
	add_child_autofree(_world)
	_game = Game.new()
	_ui = GameUI.new()
	_hud = HUD.new()
	var indicators : Array[TextureRect] = [
		TextureRect.new(), TextureRect.new(), TextureRect.new(),
	]
	_hud.indicators = indicators
	_hud.add_child(indicators[0])
	_hud.add_child(indicators[1])
	_hud.add_child(indicators[2])
	_ui.hud_root = _hud
	_game.ui_root = _ui
	GameManager.game = _game
	_saved_ads_hold = GameSettings.ads_hold_enabled
	_saved_dead = GameManager.is_player_dead
	GameManager.is_player_dead = false


func after_each() -> void:
	GameSettings.ads_hold_enabled = _saved_ads_hold
	GameManager.is_player_dead = _saved_dead
	GameManager.game = _saved_game
	# Free the stub set the hold-position tests free: the world content is
	# released by add_child_autofree, these three never enter the tree.
	_hud.free()
	_ui.free()
	_game.free()


func _physics_frames(count : int) -> void:
	for i in count:
		await get_tree().physics_frame
	_mark_preexisting_asset_noise_handled()


## The gun scenes ship broken ext_resource UIDs and old-format assets whose
## churn lives outside this lane (the webley _smoke.tscn link, the
## muzzle/Smoke30Frames effect imports flagged in git status mid-edit).
## Marking exactly those pre-existing notices handled keeps the suite scoped
## to the ADS seam; any OTHER engine error still fails.
func _mark_preexisting_asset_noise_handled() -> void:
	for err in get_errors():
		if not err.handled and (
			err.contains_text("invalid UID")
			or err.contains_text("Skeleton uses old pose format")
			or err.contains_text("Mesh uses old surface format")
		):
			err.handled = true


func _spawn_player() -> HumanoidCharacter:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 0.5, 40.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.25, 0.0)
	floor_body.add_child(shape)
	_world.add_child(floor_body)
	var player : HumanoidCharacter = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_world.add_child(player)
	await _physics_frames(5)
	return player


## Equips an equipment scene as the mainhand equipment without the full
## hotbar flow: the item lives in the tree (so %HoldPosition resolves and
## the ready-time ads_reset capture runs) and stays where it was placed.
func _equip_mainhand(player : HumanoidCharacter, scene_path : String) -> Node:
	var item : Node = (load(scene_path) as PackedScene).instantiate()
	item.name = "AdsItem"
	item.freeze = true
	_world.add_child(item)
	await _physics_frames(1)
	player.inventory.current_mainhand_equipment = item
	await _physics_frames(1)
	return item


func _controller(player : HumanoidCharacter) -> PlayerController:
	return player.get_node("PlayerController") as PlayerController


func test_ads_small_gun_fov_converges_to_65() -> void:
	var player := await _spawn_player()
	await _equip_mainhand(player, WEBLEY_SCENE)
	var pc := _controller(player)
	pc.set_ads(true)
	assert_true(pc.is_ads_active, "aiming engages ADS with a gun in the mainhand")
	await _physics_frames(SETTLE_FRAMES)
	var camera : Camera3D = player.get_node("ModelRoot/MainCamera")
	assert_lt(camera.fov, 66.0, "the small-gun fov converged to the 3.x target 65")
	assert_gt(camera.fov, 64.0, "the small-gun fov rests at the 3.x target 65")


func test_ads_medium_gun_fov_converges_to_60() -> void:
	var player := await _spawn_player()
	await _equip_mainhand(player, MARTINI_SCENE)
	var pc := _controller(player)
	pc.set_ads(true)
	await _physics_frames(SETTLE_FRAMES)
	var camera : Camera3D = player.get_node("ModelRoot/MainCamera")
	assert_lt(camera.fov, 62.0, "the medium-gun fov is converging to the 3.x target 60")
	assert_gt(camera.fov, 59.0, "the medium-gun fov approaches the 3.x target 60 from above")


func test_ads_release_restores_the_camera_baseline() -> void:
	var player := await _spawn_player()
	await _equip_mainhand(player, WEBLEY_SCENE)
	var pc := _controller(player)
	pc.set_ads(true)
	await _physics_frames(SETTLE_FRAMES)
	var camera : Camera3D = player.get_node("ModelRoot/MainCamera")
	assert_lt(camera.fov, 66.0, "sanity: the aim moved the fov off the baseline")
	pc.set_ads(false)
	await _physics_frames(SETTLE_FRAMES)
	assert_gt(camera.fov, 74.0, "release eases the fov back to the dev4 camera baseline")
	assert_false(pc.is_ads_active, "release ends the aim")


func test_ads_look_mod_reads_the_ironsight_setting_live() -> void:
	var player := await _spawn_player()
	await _equip_mainhand(player, WEBLEY_SCENE)
	var pc := _controller(player)
	Settings.set_setting(GameSettings.SETTING_ADS_LOOK_SCALE, 1.0)
	pc.set_ads(true)
	await _physics_frames(2)
	assert_eq(pc.camera_look_mod, 1.0, "a 1.0 setting restores the exact 3.x look")
	Settings.set_setting(GameSettings.SETTING_ADS_LOOK_SCALE, 0.8)
	await _physics_frames(2)
	assert_eq(pc.camera_look_mod, 0.8, "the setting applies live without a restart")
	assert_eq(GameSettings.ads_look_scale(), 0.8, "the registered default is the mild 0.8 ironsight value")
	pc.set_ads(false)
	await _physics_frames(2)
	assert_eq(pc.camera_look_mod, 1.0, "release restores the un-scaled look")
	Settings.set_setting(GameSettings.SETTING_ADS_LOOK_SCALE, GameSettings.ADS_LOOK_SCALE_DEFAULT)


func test_ads_look_setting_clamps_to_the_floor() -> void:
	Settings.set_setting(GameSettings.SETTING_ADS_LOOK_SCALE, 0.0)
	assert_eq(GameSettings.ads_look_scale(), 0.05, "a zeroed slider clamps to the 0.05 floor so look never freezes")
	Settings.set_setting(GameSettings.SETTING_ADS_LOOK_SCALE, GameSettings.ADS_LOOK_SCALE_DEFAULT)


func test_ads_consumes_the_hold_exports_and_restores() -> void:
	var player := await _spawn_player()
	var gun : GunItem = await _equip_mainhand(player, MARTINI_SCENE)
	var hold : Node3D = gun.hold_position as Node3D
	assert_ne(gun.ads_hold_position, Vector3.ZERO, "sanity: the martini ships authored ads_hold values")
	var pc := _controller(player)
	pc.set_ads(true)
	await _physics_frames(3)
	assert_true(hold.position.is_equal_approx(gun.ads_hold_position),
		"aiming drives the hold node to the authored ads_hold_position")
	assert_true(hold.rotation_degrees.is_equal_approx(gun.ads_hold_rotation),
		"aiming drives the hold node to the authored ads_hold_rotation")
	pc.set_ads(false)
	await _physics_frames(20)
	assert_true(hold.position.is_equal_approx(gun.ads_reset_position),
		"release eases the hold node back to the ready-time reset position")
	assert_true(hold.rotation_degrees.is_equal_approx(gun.ads_reset_rotation),
		"release eases the hold node back to the ready-time reset rotation")


func test_ads_drives_the_anim_tree_ads_blend_per_frame() -> void:
	var player := await _spawn_player()
	await _equip_mainhand(player, WEBLEY_SCENE)
	var pc := _controller(player)
	var tree : AnimationTree = player.get_node("CharacterAnimationTree")
	pc.set_ads(true)
	await _physics_frames(SETTLE_FRAMES)
	assert_eq(float(tree.get("parameters/ads_l/blend_amount")), 1.0, "the ads_l blend pins at 1.0 while aimed")
	assert_eq(float(tree.get("parameters/ads_r/blend_amount")), 1.0, "the ads_r blend pins at 1.0 while aimed")
	pc.set_ads(false)
	await _physics_frames(SETTLE_FRAMES)
	assert_eq(float(tree.get("parameters/ads_l/blend_amount")), 0.0, "release blends the ADS pose out")


func test_ads_hold_and_toggle_modes() -> void:
	var player := await _spawn_player()
	await _equip_mainhand(player, WEBLEY_SCENE)
	var pc := _controller(player)
	GameSettings.ads_hold_enabled = true
	pc.set_ads(true)
	assert_true(pc.is_ads_active, "hold mode: press engages")
	pc.set_ads(false)
	assert_false(pc.is_ads_active, "hold mode: release disengages")

	GameSettings.ads_hold_enabled = false
	pc.set_ads(true)
	assert_true(pc.is_ads_active, "toggle mode: a press engages")
	pc.set_ads(false)
	assert_true(pc.is_ads_active, "toggle mode: a release is inert")
	pc.set_ads(true)
	assert_false(pc.is_ads_active, "toggle mode: the next press disengages")
	GameSettings.ads_hold_enabled = true


func test_ads_gates() -> void:
	var player := await _spawn_player()
	var pc := _controller(player)
	pc.set_ads(true)
	assert_false(pc.is_ads_active, "no mainhand item means no ADS")

	await _equip_mainhand(player, LANTERN_SCENE)
	pc.set_ads(true)
	assert_false(pc.is_ads_active, "a light in the mainhand gates ADS off, per the 3.x GunItem condition")

	var gun : Node = await _equip_mainhand(player, WEBLEY_SCENE)
	player.state.is_reloading = true
	pc.set_ads(true)
	assert_false(pc.is_ads_active, "reloading gates ADS off, per the 3.x condition")
	player.state.is_reloading = false

	pc.input.sprint = true
	pc.set_ads(true)
	assert_false(pc.is_ads_active, "sprinting gates ADS off, per the 3.x condition")
	pc.input.sprint = false

	GameManager.is_player_dead = true
	pc.set_ads(true)
	assert_false(pc.is_ads_active, "a dead player cannot start ADS")


func test_ads_ends_when_the_gun_leaves_mid_hold() -> void:
	var player := await _spawn_player()
	var gun : Node = await _equip_mainhand(player, WEBLEY_SCENE)
	var pc := _controller(player)
	pc.set_ads(true)
	await _physics_frames(2)
	assert_true(pc.is_ads_active, "sanity: aiming engaged")
	player.inventory.current_mainhand_equipment = null
	await _physics_frames(2)
	assert_false(pc.is_ads_active, "the gun leaving the mainhand ends the aim")
	assert_true(is_instance_valid(gun), "the test gun stays alive for the fixture cleanup")


func test_ads_ends_when_the_player_dies_mid_hold() -> void:
	var player := await _spawn_player()
	await _equip_mainhand(player, WEBLEY_SCENE)
	var pc := _controller(player)
	pc.set_ads(true)
	await _physics_frames(2)
	GameManager.is_player_dead = true
	await _physics_frames(2)
	assert_false(pc.is_ads_active, "death ends the aim so no ADS write fights the death cam")
	GameManager.is_player_dead = false


func test_spyglass_zoom_sets_the_look_mod_and_restores() -> void:
	var player := await _spawn_player()
	var camera : Camera3D = player.get_node("ModelRoot/MainCamera")
	var zoom : Node = (load(ZOOM_CONTROLLER_SCRIPT) as GDScript).new()
	zoom.name = "SpyglassZoomController"
	camera.add_child(zoom)
	zoom.setup(camera, player.inventory, _controller(player))
	player.inventory.tiny_items[load(SPYGLASS_RESOURCE)] = 1
	# The zoom is driven directly: the input actions cannot be synthesized
	# headlessly, and _apply_look_mod / _apply_fov are the exact seam calls
	# the per-frame loop makes.
	zoom._zooming = true
	zoom._apply_look_mod()
	zoom._apply_fov()
	assert_eq(_controller(player).camera_look_mod, 0.25, "the zoomed look is the 3.x zoom_camera_sens_mod 0.25")
	assert_lt(camera.fov, CAMERA_BASELINE_FOV, "the zoom moves the fov toward its target")
	zoom._zooming = false
	zoom._apply_look_mod()
	zoom._apply_fov()
	assert_eq(_controller(player).camera_look_mod, 1.0, "releasing the zoom restores the un-scaled look")


func test_spyglass_restore_stands_down_while_ads_owns_the_fov() -> void:
	var player := await _spawn_player()
	var camera : Camera3D = player.get_node("ModelRoot/MainCamera")
	var zoom : Node = (load(ZOOM_CONTROLLER_SCRIPT) as GDScript).new()
	zoom.name = "SpyglassZoomController"
	camera.add_child(zoom)
	zoom.setup(camera, player.inventory, _controller(player))
	var pc := _controller(player)
	await _equip_mainhand(player, WEBLEY_SCENE)
	pc.set_ads(true)
	await _physics_frames(10)
	var ads_fov : float = camera.fov
	zoom._zooming = false
	zoom._apply_fov()
	assert_eq(camera.fov, ads_fov, "the spyglass restore does not fight the ADS fov while aimed")
	zoom._zooming = true
	zoom._apply_fov()
	await _physics_frames(2)
	assert_lt(camera.fov, 70.0, "an active zoom keeps zooming even with ADS engaged")
