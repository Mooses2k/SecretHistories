extends GutTest
## Equip/unequip arm animation states restored from 3.x
## (parity-missed-audit.md M9, P2). 3.x truth: the player animation was NOT
## a draw one-shot: the unequip signals (origin/main inventory.gd:275,359)
## switched the player tree to the empty pose immediately (player_anims.gd
## 270-279) and the post-coroutine inventory_changed (inventory.gd:237,263)
## settled the item hold pose (player_anims.gd:253-258, 58-236); the belt
## stow played the Belt_Equip clip on the AdditionalAnimations player
## (inventory.gd:534-541). Dev4 maps the same pose vocabulary onto the
## humanoid tree's equip_hold_r / equip_hold_l Blend2s and keeps the 3.x
## signal timing (unequip instant, equip after the 0.5 s coroutine).

const BASE_SCENE := "res://scenes/characters/humanoid_character_base/humanoid_character_base.tscn"
const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const UI_SCENE := preload("res://scenes/ui/game_ui.tscn")
const WEBLEY_SCENE := "res://scenes/objects/pickable_items/equipment/ranged/webley_revolver/webley.tscn"
const DARK_LANTERN_SCENE := "res://scenes/objects/pickable_items/equipment/tool/light-sources/belt_clip_dark_lantern/dark_lantern.tscn"

const EQUIP_HOLD_R := "parameters/equip_hold_r/blend_amount"
const EQUIP_HOLD_L := "parameters/equip_hold_l/blend_amount"
const HOLD_POSE_R := "parameters/hold_pose_r/blend_amount"
const HOLD_ITEM_R := "parameters/hold_item_r/blend_amount"
const HOLD_ITEM_L := "parameters/hold_item_l/blend_amount"
const POSE_SETTLE := 0.3

var _character : Node = null
var _game : Game = null
var _saved_game : Game = null
var _world : Node3D = null
var _inventory_changed_count : int = 0


func _count_inventory_changed() -> void:
	_inventory_changed_count += 1


func before_each() -> void:
	_character = (load(BASE_SCENE) as PackedScene).instantiate()
	add_child_autofree(_character)
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	if _world != null:
		_world.free()
		_world = null
	if _game != null:
		_game.free()
		_game = null
	GameManager.game = _saved_game


func _tree() -> AnimationTree:
	return _character.get_node("CharacterAnimationTree") as AnimationTree


func _inv() -> Inventory:
	return _character.get_node("Inventory") as Inventory


func _pose(param : String) -> float:
	return float(_tree().get(param))


func _settle_pose() -> void:
	await get_tree().create_timer(POSE_SETTLE).timeout


func _connection_map() -> Dictionary:
	var blend_tree := _tree().tree_root as AnimationNodeBlendTree
	var pairs := {}
	var conns : Array = blend_tree.node_connections
	var i := 0
	while i < conns.size():
		pairs[String(conns[i]) + ":" + str(conns[i + 1])] = String(conns[i + 2])
		i += 3
	return pairs


func _clip_for(node_name : String) -> String:
	var blend_tree := _tree().tree_root as AnimationNodeBlendTree
	return String((blend_tree.get_node(node_name) as AnimationNodeAnimation).animation)


func _spawn_gun() -> Node:
	# Out-of-tree spawn (autofree-tracked): the pose logic only needs the
	# scene's exported state, and the caller parents the gun into the hand
	# root directly (a tree pre-add would double-parent it).
	var gun : Node = (load(WEBLEY_SCENE) as PackedScene).instantiate()
	autofree(gun)
	gun.item_state = GlobalConsts.ItemState.EQUIPPED
	return gun


func _tolerate_light_harness_artifacts() -> void:
	# Harness-only engine noise, same list as test_belt_hook.gd: the
	# belt-clip lantern's cone re-triangulation, the game_ui anchors
	# warning, and the reparent chatter.
	for e in gut.error_tracker.get_current_test_errors():
		var text := String(e.code) + " " + String(e.rationale)
		if text.contains("Too few vertices per face") \
				or text.contains("already has a parent") \
				or text.contains("p_child->data.parent") \
				or text.contains("non-equal opposite anchors"):
			e.handled = true


func _spawn_lantern() -> Node:
	# Out-of-tree spawn, light_detection stripped before entering the tree
	# (cone re-triangulation noise; same discipline as test_belt_hook.gd).
	var light : Node = (load(DARK_LANTERN_SCENE) as PackedScene).instantiate()
	autofree(light)
	for detection in _nodes_with_script_path(light, "light_detection"):
		if is_instance_valid(detection):
			detection.free()
	return light


func _nodes_with_script_path(node : Node, needle : String) -> Array:
	var found := []
	for child in node.get_children():
		var script : GDScript = child.get_script()
		if script != null and script.resource_path.contains(needle):
			found.append(child)
		found.append_array(_nodes_with_script_path(child, needle))
	return found


func _spawn_player() -> Node:
	# Same stub set as test_belt_hook.gd: the real player scene ticks
	# interact_controller, which reads GameManager.game.ui_root every frame.
	_saved_game = GameManager.game
	_game = Game.new()
	GameManager.game = _game
	var ui : Node = UI_SCENE.instantiate()
	add_child_autofree(ui)
	_game.ui_root = ui
	_world = Node3D.new()
	_world.name = "TestWorld"
	add_child_autofree(_world)
	var player : Node = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_world.add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	return player


func test_tree_carries_the_equip_hold_nodes_with_the_3x_clips() -> void:
	var pairs := _connection_map()
	var blend_tree := _tree().tree_root as AnimationNodeBlendTree
	for node_name in ["equip_hold_r", "equip_hold_l", "hold_pose_r", "hold_item_r", "hold_item_l"]:
		assert_true(blend_tree.has_node(node_name), "missing hold node " + node_name)
	assert_eq(pairs["gun_ready_r:0"], "equip_hold_r", "the right hold blend feeds the gun-ready chain")
	assert_eq(pairs["equip_hold_r:0"], "grounded", "unarmed passes the natural arm flow")
	assert_eq(pairs["equip_hold_r:1"], "hold_pose_r")
	assert_eq(pairs["hold_pose_r:0"], "hold_item_r")
	assert_eq(pairs["hold_pose_r:1"], "_hold_gun_r")
	assert_eq(_clip_for("_hold_gun_r"), "movement_and_aiming/ads_idle")
	assert_eq(_clip_for("_hold_vertical_r"), "movement_and_aiming/item_holding_vertical")
	assert_eq(_clip_for("_hold_horizontal_r"), "movement_and_aiming/item_holding_horizontal")
	assert_eq(_clip_for("_hold_vertical_l"), "movement_and_aiming/item_holding_vertical_L")
	assert_eq(_clip_for("_hold_horizontal_l"), "movement_and_aiming/item_holding_horizonta_L")
	assert_eq(pairs["attack_cut:0"], "equip_hold_l", "the left hold blend feeds the melee chain")
	assert_eq(pairs["equip_hold_l:0"], "gun_ready_l")
	assert_eq(pairs["equip_hold_l:1"], "hold_item_l")


func test_unarmed_hands_stay_in_the_natural_arm_flow() -> void:
	_tree().update_equipment_pose()
	await _settle_pose()
	assert_almost_eq(_pose(EQUIP_HOLD_R), 0.0, 0.01, "empty mainhand holds no pose")
	assert_almost_eq(_pose(EQUIP_HOLD_L), 0.0, 0.01, "empty offhand holds no pose")


func test_mainhand_gun_holds_the_raised_pose() -> void:
	var gun := await _spawn_gun()
	_inv().current_mainhand_equipment = gun
	_character.main_hand_root.add_child(gun)
	_inv().emit_signal("inventory_changed")
	await _settle_pose()
	assert_almost_eq(_pose(EQUIP_HOLD_R), 1.0, 0.01, "the mainhand arm raises for a gun")
	assert_almost_eq(_pose(HOLD_POSE_R), 1.0, 0.01, "the gun selects the raised gun pose")


func test_mainhand_item_picks_vertical_or_horizontal_by_flag() -> void:
	var light := _spawn_lantern()
	_inv().current_mainhand_equipment = light
	_character.main_hand_root.add_child(light)
	_inv().emit_signal("inventory_changed")
	await _settle_pose()
	assert_almost_eq(_pose(EQUIP_HOLD_R), 1.0, 0.01)
	assert_almost_eq(_pose(HOLD_POSE_R), 0.0, 0.01, "a non-gun item does not use the gun pose")
	assert_almost_eq(_pose(HOLD_ITEM_R), 0.0, 0.01, "a vertical item holds vertical")
	light.horizontal_holding = true
	_inv().emit_signal("inventory_changed")
	await _settle_pose()
	assert_almost_eq(_pose(HOLD_ITEM_R), 1.0, 0.01, "a horizontal item holds horizontal")


func test_offhand_item_holds_the_left_pose() -> void:
	var light := _spawn_lantern()
	_inv().current_offhand_equipment = light
	_character.off_hand_root.add_child(light)
	_inv().emit_signal("inventory_changed")
	await _settle_pose()
	assert_almost_eq(_pose(EQUIP_HOLD_L), 1.0, 0.01, "the offhand arm raises for an item")
	assert_almost_eq(_pose(HOLD_ITEM_L), 0.0, 0.01, "the left hold defaults to vertical")


func test_offhand_gun_stays_in_the_natural_flow() -> void:
	# Asset-blocked pin: 3.x used LeftHanded_Pistol_Hold for an offhand gun
	# (player_anims.gd:69, player.tscn OffHand_Weapon_States state 1); dev4
	# has no left-hand gun hold clip, so the left arm keeps the natural flow.
	var gun := await _spawn_gun()
	_inv().current_offhand_equipment = gun
	_character.off_hand_root.add_child(gun)
	_inv().emit_signal("inventory_changed")
	await _settle_pose()
	assert_almost_eq(_pose(EQUIP_HOLD_L), 0.0, 0.01, "no left gun pose until the asset lands")


func test_unequip_signals_drop_the_pose_immediately() -> void:
	var light := _spawn_lantern()
	_inv().current_mainhand_equipment = light
	_character.main_hand_root.add_child(light)
	_inv().emit_signal("inventory_changed")
	await _settle_pose()
	assert_almost_eq(_pose(EQUIP_HOLD_R), 1.0, 0.01, "precondition: armed")
	# The 3.x timing: the unequip signal fires at the unequip (origin/main
	# inventory.gd:275), before the equip coroutine of the next press.
	_inv().current_mainhand_equipment = null
	_inv().emit_signal("unequip_mainhand")
	await _settle_pose()
	assert_almost_eq(_pose(EQUIP_HOLD_R), 0.0, 0.01, "the arm drops on the unequip")
	_inv().emit_signal("unequip_offhand")
	await _settle_pose()
	assert_almost_eq(_pose(EQUIP_HOLD_L), 0.0, 0.01, "the offhand drops on its unequip")


func test_real_offhand_equip_raises_the_left_arm_after_the_delay() -> void:
	var light := _spawn_lantern()
	var inv := _inv()
	inv.hotbar[10] = light
	light.item_state = GlobalConsts.ItemState.EQUIPPED
	inv.current_offhand_slot = 10
	_inventory_changed_count = 0
	inv.inventory_changed.connect(_count_inventory_changed)
	inv.equip_offhand_item()
	# The landed equip coroutine delay (inventory.gd:821-827) runs first;
	# the pose rises only after the item lands in the hand, exactly the 3.x
	# post-coroutine coupling.
	await get_tree().create_timer(0.1).timeout
	assert_almost_eq(_pose(EQUIP_HOLD_L), 0.0, 0.01, "the arm stays natural during the equip delay")
	await get_tree().create_timer(0.7).timeout
	assert_eq(inv.current_offhand_equipment, light, "the item equipped")
	assert_gt(_inventory_changed_count, 0, "the equip emitted inventory_changed")
	await _settle_pose()
	assert_almost_eq(_pose(EQUIP_HOLD_L), 1.0, 0.01, "the arm raised after the equip delay")
	inv.inventory_changed.disconnect(_count_inventory_changed)


func test_belt_stow_plays_belt_equip_when_the_clip_exists() -> void:
	var player : Node = await _spawn_player()
	var anim_player := player.get_node("AnimationPlayer") as AnimationPlayer
	assert_false(anim_player.has_animation("Belt_Equip"),
			"precondition: dev4 content carries no Belt_Equip clip (asset-blocked)")
	var library := anim_player.get_animation_library(&"")
	library.add_animation("Belt_Equip", Animation.new())
	var light := _spawn_lantern()
	var inv : Inventory = player.get_node("Inventory")
	inv.hotbar[0] = light
	light.item_state = GlobalConsts.ItemState.EQUIPPED
	inv.current_mainhand_equipment = light
	player.main_hand_root.add_child(light)
	# The 3.x stow moment: the hand unequip routes the belt-capable lantern
	# onto the belt (inventory.gd _belt_stow_if_capable) and plays the clip.
	inv.unequip_mainhand_item()
	await get_tree().process_frame
	_tolerate_light_harness_artifacts()
	assert_eq(light.get_parent(), player.get("belt_position"), "the lantern stowed on the belt")
	assert_eq(anim_player.current_animation, "Belt_Equip", "the belt stow played the belt clip")
	library.remove_animation("Belt_Equip")


func test_belt_stow_without_the_clip_is_a_clean_noop() -> void:
	var player : Node = await _spawn_player()
	var anim_player := player.get_node("AnimationPlayer") as AnimationPlayer
	var light := _spawn_lantern()
	var inv : Inventory = player.get_node("Inventory")
	inv.hotbar[0] = light
	light.item_state = GlobalConsts.ItemState.EQUIPPED
	inv.current_mainhand_equipment = light
	player.main_hand_root.add_child(light)
	inv.unequip_mainhand_item()
	await get_tree().process_frame
	_tolerate_light_harness_artifacts()
	assert_eq(light.get_parent(), player.get("belt_position"), "the lantern stowed on the belt")
	assert_eq(anim_player.current_animation, "", "no clip played: the asset is blocked")
	for e in gut.error_tracker.get_current_test_errors():
		var text := String(e.code) + " " + String(e.rationale)
		assert_false(text.contains("SCRIPT ERROR"), "the missing clip must not error")
