extends GutTest
## Belt hook restored from 3.x (parity-missed-audit.md M1, P0): a can_attach
## lantern put away from a hand stows onto the player rig's BeltPosition and
## keeps burning, F/N release toggles the belt lantern light first (then the
## offhand item, then the mainhand item), a hotbar slot press takes it back,
## and rigs without the belt marker keep the plain put-away extinguish
## (#644). 3.x truth: character.tscn:160 BeltPosition marker, inventory.gd
## 525-541 with lanterns.gd 82-95 stow flow, player_controller.gd 611-617 F
## release chain, inventory equip pull 257-260 / 344-347, drop clear 401-405.

const PLAYER_SCENE := "res://scenes/characters/player/player.tscn"
const BASE_SCENE := "res://scenes/characters/humanoid_character_base/humanoid_character_base.tscn"
const UI_SCENE := preload("res://scenes/ui/game_ui.tscn")
const DARK_LANTERN_SCENE := "res://scenes/objects/pickable_items/equipment/tool/light-sources/belt_clip_dark_lantern/dark_lantern.tscn"
const BELT_ACTION := "ablty|nightvision_darksight"
const BELT_MARKER_TRANSLATION := Vector3(0.2, 1.2, -0.3)

var _game : Game = null
var _saved_game : Game = null
var _world : Node3D = null


func before_each() -> void:
	_saved_game = GameManager.game


func after_each() -> void:
	if Input.is_action_pressed(BELT_ACTION):
		Input.action_release(BELT_ACTION)
	if _world != null:
		_world.free()
		_world = null
	if _game != null:
		_game.free()
		_game = null
	GameManager.game = _saved_game


func _spawn_player() -> Node:
	# Same stub set as test_spyglass_zoom.gd: the real player scene ticks
	# interact_controller, which reads GameManager.game.ui_root every frame.
	# The world is named TestWorld so inventory._drop_item can route a
	# dropped belt lantern into it headlessly.
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


func _spawn_base() -> Node:
	var character : Node = (load(BASE_SCENE) as PackedScene).instantiate()
	add_child_autofree(character)
	await get_tree().process_frame
	await get_tree().process_frame
	return character


func _spawn_lantern() -> Node:
	# Out-of-tree spawn for the equip harnesses: the light_detection subtree
	# is stripped before the lantern enters the tree (its cone
	# re-triangulates every frame and spams a benign engine warning; same
	# discipline as test_light_stow_extinguish.gd).
	var light : Node = (load(DARK_LANTERN_SCENE) as PackedScene).instantiate()
	autofree(light)
	for detection in _nodes_with_script_path(light, "light_detection"):
		if is_instance_valid(detection):
			detection.free()
	return light


func _spawn_lantern_in_tree() -> Node:
	var light : Node = (load(DARK_LANTERN_SCENE) as PackedScene).instantiate()
	add_child_autofree(light)
	await get_tree().process_frame
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


func _equip_mainhand_light(inv : Inventory, character : Node, light : Node) -> void:
	inv.hotbar[0] = light
	light.item_state = GlobalConsts.ItemState.EQUIPPED
	inv.current_mainhand_equipment = light
	character.main_hand_root.add_child(light)


func _equip_offhand_light(inv : Inventory, character : Node, light : Node, slot : int = 10) -> void:
	# Slot written directly: the setter would arm a delayed equip mid-test
	# (same rule as test_light_stow_extinguish.gd).
	inv.hotbar[slot] = light
	light.item_state = GlobalConsts.ItemState.EQUIPPED
	inv.current_offhand_equipment = light
	if slot != 10:
		inv.current_offhand_slot = slot
	character.off_hand_root.add_child(light)


func _tolerate_light_harness_artifacts() -> void:
	# Harness-only engine noise, same discipline as test_light_stow_extinguish.gd:
	# the belt-clip lantern's cone re-triangulation, the reparent parent
	# chatter, and the landed game_ui.gd:47 set_size against full-rect
	# anchors, which warns on every headless GUT instantiation of game_ui.
	for e in gut.error_tracker.get_current_test_errors():
		var text := String(e.code) + " " + String(e.rationale)
		if text.contains("Too few vertices per face") \
				or text.contains("already has a parent") \
				or text.contains("p_child->data.parent") \
				or text.contains("non-equal opposite anchors"):
			e.handled = true


func _physics_frames(count : int) -> void:
	for i in count:
		await get_tree().physics_frame


func test_player_rig_authors_the_belt_position_marker() -> void:
	var player : Node = await _spawn_player()
	_tolerate_light_harness_artifacts()
	var marker := player.get("belt_position") as Marker3D
	assert_not_null(marker, "the player exposes belt_position resolving to the marker")
	assert_eq(marker.name, "BeltPosition", "the marker keeps the 3.x name")
	assert_eq(marker.get_parent(), player, "the marker hangs on the player root")
	assert_eq(marker.position, BELT_MARKER_TRANSLATION, "the marker keeps the 3.x translation")


func test_bare_humanoid_has_no_belt_property() -> void:
	var base : Node = await _spawn_base()
	assert_null(base.get("belt_position"), "the bare humanoid carries no belt property")


func test_mainhand_stow_attaches_a_lit_lantern_to_the_belt() -> void:
	var player : Node = await _spawn_player()
	var inv : Inventory = player.get_node("Inventory") as Inventory
	var light : Node = _spawn_lantern()
	_equip_mainhand_light(inv, player, light)
	await get_tree().process_frame
	light.light()
	assert_true(light.is_lit, "precondition: the lantern is lit")

	inv.set_mainhand_slot(1)
	# equip_mainhand_item is a delayed coroutine (0.5 s draw); let the
	# empty-slot equip resolve so no pending call crosses the assert block.
	await get_tree().create_timer(0.7).timeout

	_tolerate_light_harness_artifacts()
	assert_true(light.is_in_belt, "the stowed lantern is flagged is_in_belt")
	assert_eq(light.get_parent(), player.get("belt_position"), "the lantern parents under BeltPosition")
	assert_eq(inv.belt_item, light, "the inventory tracks the belt item")
	assert_true(light.is_lit, "the belt lantern keeps burning (3.x parity)")
	assert_true(light.firelight.visible, "the flame stays on")
	assert_false(light.mesh_instance.visible, "the belt lantern mesh is hidden")
	assert_null(inv.current_mainhand_equipment, "the lantern left the hand")


func test_belt_lantern_burns_fuel_while_stowed() -> void:
	var player : Node = await _spawn_player()
	var inv : Inventory = player.get_node("Inventory") as Inventory
	var light : Node = _spawn_lantern()
	_equip_mainhand_light(inv, player, light)
	await get_tree().process_frame
	light.light()

	inv.set_mainhand_slot(1)
	await get_tree().create_timer(0.7).timeout
	_tolerate_light_harness_artifacts()
	assert_true(light.is_lit, "precondition: the lantern burns on the belt")

	var fill_before : float = light.fuel.fill
	light._process(60.0)

	_tolerate_light_harness_artifacts()
	assert_true(light.is_lit, "still burning after the simulated burn tick")
	assert_lt(light.fuel.fill, fill_before, "the belt lantern consumes fuel while stowed")


func test_hotbar_slot_press_takes_the_lantern_back_off_the_belt() -> void:
	var player : Node = await _spawn_player()
	var inv : Inventory = player.get_node("Inventory") as Inventory
	var light : Node = _spawn_lantern()
	_equip_mainhand_light(inv, player, light)
	await get_tree().process_frame
	light.light()

	inv.set_mainhand_slot(1)
	await get_tree().create_timer(0.7).timeout
	_tolerate_light_harness_artifacts()
	assert_true(light.is_in_belt, "precondition: the lantern rides the belt")

	inv.set_mainhand_slot(0)
	# The take-back equip is the same delayed coroutine: it completes the
	# belt pull on resume.
	await get_tree().create_timer(0.7).timeout

	_tolerate_light_harness_artifacts()
	assert_eq(light.get_parent(), player.main_hand_root, "the slot press took the lantern back into the hand")
	assert_false(light.is_in_belt, "the belt flag cleared on take-back")
	assert_null(inv.belt_item, "the belt slot is empty again")
	assert_true(light.mesh_instance.visible, "the mesh is visible again")
	assert_true(light.is_lit, "the lantern comes back still burning")
	assert_eq(inv.current_mainhand_equipment, light, "the lantern is equipped again")


func test_offhand_stow_and_take_back_round_trip() -> void:
	var player : Node = await _spawn_player()
	var inv : Inventory = player.get_node("Inventory") as Inventory
	var light : Node = _spawn_lantern()
	_equip_offhand_light(inv, player, light, 2)
	await get_tree().process_frame
	light.light()

	inv.set_offhand_slot(3)

	_tolerate_light_harness_artifacts()
	assert_true(light.is_in_belt, "the offhand stow belts the lantern")
	assert_eq(light.get_parent(), player.get("belt_position"), "the lantern parents under BeltPosition")
	assert_true(light.is_lit, "the belt lantern keeps burning")

	# Let the empty-slot offhand equip resolve before the take-back press so
	# the two delayed coroutines never interleave.
	await get_tree().create_timer(0.7).timeout
	inv.set_offhand_slot(2)
	await get_tree().create_timer(0.7).timeout

	_tolerate_light_harness_artifacts()
	assert_eq(light.get_parent(), player.off_hand_root, "the offhand slot press took the lantern back")
	assert_false(light.is_in_belt, "the belt flag cleared")
	assert_null(inv.belt_item, "the belt slot is empty")
	assert_eq(inv.current_offhand_equipment, light, "the lantern is offhand-equipped again")


func test_same_slot_holster_press_belts_the_lantern() -> void:
	var player : Node = await _spawn_player()
	var inv : Inventory = player.get_node("Inventory") as Inventory
	var light : Node = _spawn_lantern()
	_equip_mainhand_light(inv, player, light)
	await get_tree().process_frame
	light.light()

	inv.set_mainhand_slot(0)

	_tolerate_light_harness_artifacts()
	assert_true(light.is_in_belt, "the same-slot holster press belts the lantern")
	assert_eq(light.get_parent(), player.get("belt_position"), "the lantern parents under BeltPosition")
	assert_true(light.is_lit, "the belt lantern keeps burning")


func test_f_release_toggles_the_belt_lantern_light() -> void:
	var player : Node = await _spawn_player()
	var inv : Inventory = player.get_node("Inventory") as Inventory
	var light : Node = _spawn_lantern()
	_equip_mainhand_light(inv, player, light)
	await get_tree().process_frame
	light.light()

	inv.set_mainhand_slot(1)
	await get_tree().create_timer(0.7).timeout
	_tolerate_light_harness_artifacts()
	assert_true(light.is_lit, "precondition: the belt lantern burns")

	Input.action_press(BELT_ACTION)
	await _physics_frames(2)
	Input.action_release(BELT_ACTION)
	await _physics_frames(2)

	_tolerate_light_harness_artifacts()
	assert_false(light.is_lit, "releasing F extinguishes the belt lantern")
	assert_false(light.firelight.visible, "the flame is off")

	Input.action_press(BELT_ACTION)
	await _physics_frames(2)
	Input.action_release(BELT_ACTION)
	await _physics_frames(2)

	_tolerate_light_harness_artifacts()
	assert_true(light.is_lit, "releasing F again relights the belt lantern")
	assert_true(light.firelight.visible, "the flame is back on")


func test_f_release_falls_back_to_the_offhand_then_mainhand_item() -> void:
	var player : Node = await _spawn_player()
	var inv : Inventory = player.get_node("Inventory") as Inventory
	var off_light : Node = _spawn_lantern()
	_equip_offhand_light(inv, player, off_light, 5)
	await get_tree().process_frame

	Input.action_press(BELT_ACTION)
	await _physics_frames(2)
	Input.action_release(BELT_ACTION)
	await _physics_frames(2)

	_tolerate_light_harness_artifacts()
	assert_true(off_light.is_lit, "with an empty belt, F release uses the offhand item")

	inv.current_offhand_equipment = null
	var main_light : Node = _spawn_lantern()
	_equip_mainhand_light(inv, player, main_light)
	await get_tree().process_frame

	Input.action_press(BELT_ACTION)
	await _physics_frames(2)
	Input.action_release(BELT_ACTION)
	await _physics_frames(2)

	_tolerate_light_harness_artifacts()
	assert_true(main_light.is_lit, "with an empty belt and offhand, F release uses the mainhand item")


func test_no_belt_rig_still_extinguishes_on_stow() -> void:
	var character : Node = await _spawn_base()
	var inv : Inventory = character.get_node("Inventory") as Inventory
	var light : Node = _spawn_lantern()
	_equip_mainhand_light(inv, character, light)
	await get_tree().process_frame
	light.light()
	assert_true(light.is_lit, "precondition: the lantern is lit")

	inv.set_mainhand_slot(1)

	_tolerate_light_harness_artifacts()
	assert_false(light.is_lit, "a rig without the belt keeps the put-away extinguish (#644)")
	assert_false(light.is_in_belt, "no belt flag is set")
	assert_null(inv.belt_item, "no belt item tracked")
	assert_null(character.get("belt_position"), "the belt lookup stays null-safe")


func test_attach_to_belt_is_a_null_safe_noop_without_a_belt() -> void:
	var character : Node = await _spawn_base()
	var inv : Inventory = character.get_node("Inventory") as Inventory
	var light : Node = await _spawn_lantern_in_tree()
	var parent_before : Node = light.get_parent()

	inv.attach_to_belt(light)

	_tolerate_light_harness_artifacts()
	assert_false(light.is_in_belt, "the flag stays false without a belt")
	assert_null(inv.belt_item, "no belt item tracked")
	assert_eq(light.get_parent(), parent_before, "the item was not reparented")


func test_no_belt_unequip_keeps_the_plain_unparent_invariant() -> void:
	var character : Node = await _spawn_base()
	var inv : Inventory = character.get_node("Inventory") as Inventory
	var light : Node = _spawn_lantern()
	_equip_mainhand_light(inv, character, light)
	await get_tree().process_frame

	inv.unequip_mainhand_item()

	_tolerate_light_harness_artifacts()
	assert_null(light.get_parent(), "the plain unequip unparents the item")
	assert_false(light.is_in_belt, "no belt flag without a belt")


func test_dropping_the_belt_lantern_clears_the_belt_state() -> void:
	var player : Node = await _spawn_player()
	var inv : Inventory = player.get_node("Inventory") as Inventory
	var light : Node = _spawn_lantern()
	_equip_mainhand_light(inv, player, light)
	await get_tree().process_frame
	light.light()

	inv.set_mainhand_slot(1)
	await get_tree().create_timer(0.7).timeout
	_tolerate_light_harness_artifacts()
	assert_true(light.is_in_belt, "precondition: the lantern rides the belt")

	inv.drop_hotbar_slot(0)

	_tolerate_light_harness_artifacts()
	assert_false(light.is_in_belt, "the drop clears the belt flag")
	assert_null(inv.belt_item, "the belt slot is empty")
	assert_eq(light.item_state, GlobalConsts.ItemState.DROPPED, "the lantern is dropped to the world")
	assert_eq(light.get_parent(), _world, "the lantern dropped into the test world")
	assert_true(light.mesh_instance.visible, "the dropped lantern is visible")


func test_belt_state_is_save_safe() -> void:
	var light : Node = await _spawn_lantern_in_tree()
	assert_false(light.is_in_belt, "a fresh item defaults is_in_belt false")
	var player : Node = await _spawn_player()
	var inv : Inventory = player.get_node("Inventory") as Inventory

	var slot : int = inv.place_in_hotbar(light)
	await get_tree().create_timer(0.7).timeout

	_tolerate_light_harness_artifacts()
	assert_true(slot >= 0, "a restored belt-era item lands in a hotbar slot")
	assert_false(light.is_in_belt, "the restore path brings the item back unattached")
	assert_null(inv.belt_item, "no belt item after restore")
	assert_eq(inv.current_offhand_equipment, light, "the restored item equips like any hotbar item")


func test_the_darksight_action_stays_registered_for_f() -> void:
	assert_true(InputMap.has_action(BELT_ACTION), "the belt release action is registered")
	var events := InputMap.action_get_events(BELT_ACTION)
	var has_f := false
	for event in events:
		var key := event as InputEventKey
		if key != null and key.keycode == KEY_F:
			has_f = true
	assert_true(has_f, "the action defaults to the F key")

