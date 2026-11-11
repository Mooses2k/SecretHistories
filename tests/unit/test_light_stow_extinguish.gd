extends GutTest
## Light stow extinguish (owner ruling 2026-11-09, issue #644): a lit
## light-source that is put away goes out. The belt-hook dark lantern is the
## one exception: a can_attach light belt-stowed via attach_to_belt
## (is_in_belt) keeps burning under its hood. Pins: hotbar switch stow, the
## same-key toggle (the de facto light holster), the offhand cycle stow, the
## reload offhand clear, the belt-hook exemption, burn-state consistency,
## pickup stow vs pickup auto-equip, hand-swap keep-lit, and drop-to-world
## keep-lit. Humanoid rigs carry no belt_position node, so the belt-hook
## exemption is exercised at the attach-state flag level (the same discipline
## test_can_attach_reequip.gd documents).

const HUMANOID_BASE_SCENE := "res://scenes/characters/humanoid_character_base/humanoid_character_base.tscn"
const DARK_LANTERN_SCENE := "res://scenes/objects/pickable_items/equipment/tool/light-sources/belt_clip_dark_lantern/dark_lantern.tscn"
const CANDLE_SCENE := "res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle.tscn"
const WEBLEY_SCENE := "res://scenes/objects/pickable_items/equipment/ranged/webley_revolver/webley.tscn"

var _character : Node = null
var _inv : Inventory = null


func before_each() -> void:
	_character = (load(HUMANOID_BASE_SCENE) as PackedScene).instantiate()
	add_child_autofree(_character)
	await get_tree().process_frame
	await get_tree().process_frame
	_inv = _character.get_node("Inventory") as Inventory


func _spawn_lantern() -> Node:
	# The lantern stays OUT of the scene tree until the code under test
	# parents it to a hand root (same harness shape as
	# test_can_attach_reequip.gd). The light_detection subtree is stripped:
	# its cone re-triangulates every frame and spams a benign engine warning.
	var light : Node = (load(DARK_LANTERN_SCENE) as PackedScene).instantiate()
	autofree(light)
	light.is_in_belt = false
	for detection in _nodes_with_script_path(light, "light_detection"):
		if is_instance_valid(detection):
			detection.free()
	return light


## In-tree spawn for paths that need _ready to have built the fuel state
## without an equip (drop-to-world, belt-flag checks).
func _spawn_lantern_in_tree() -> Node:
	var light : Node = (load(DARK_LANTERN_SCENE) as PackedScene).instantiate()
	add_child_autofree(light)
	for detection in _nodes_with_script_path(light, "light_detection"):
		if is_instance_valid(detection):
			detection.free()
	return light


func _spawn_candle() -> Node:
	var candle : Node = (load(CANDLE_SCENE) as PackedScene).instantiate()
	add_child_autofree(candle)
	return candle


func _nodes_with_script_path(node : Node, needle : String) -> Array:
	var found := []
	for child in node.get_children():
		var script : GDScript = child.get_script()
		if script != null and script.resource_path.contains(needle):
			found.append(child)
		found.append_array(_nodes_with_script_path(child, needle))
	return found


func _tolerate_light_harness_artifacts() -> void:
	# Harness-only engine noise: the belt-clip lantern's cone
	# re-triangulation plus the can_attach re-add parent chatter that
	# test_reload_character_anim.gd already tolerates.
	for e in gut.error_tracker.get_current_test_errors():
		var text := String(e.code) + " " + String(e.rationale)
		if text.contains("Too few vertices per face") \
				or text.contains("already has a parent") \
				or text.contains("p_child->data.parent"):
			e.handled = true


## The webley scene chain currently carries invalid resource UIDs (the
## effects .import files are mid-edit by another lane): the load falls back
## to text paths and stays functional. Tolerated ONLY in the reload test,
## the one test that loads the webley; a real break elsewhere still fails.
func _tolerate_webley_uid_drift() -> void:
	for e in gut.error_tracker.get_current_test_errors():
		var text := String(e.code) + " " + String(e.rationale)
		if text.contains("invalid UID") or text.contains("using text path instead"):
			e.handled = true


func _equip_mainhand_light(light : Node) -> void:
	_inv.hotbar[0] = light
	light.item_state = GlobalConsts.ItemState.EQUIPPED
	_inv.current_mainhand_equipment = light
	_character.main_hand_root.add_child(light)


func _equip_offhand_light(light : Node, slot : int = 10) -> void:
	# Slot written directly: the setter would arm a delayed equip that
	# undoes the test's unequips mid-flight (same rule as
	# test_reload_character_anim.gd). A non-10 slot keeps
	# current_offhand_slot in sync through its bookkeeping branch.
	_inv.hotbar[slot] = light
	light.item_state = GlobalConsts.ItemState.EQUIPPED
	_inv.current_offhand_equipment = light
	if slot != 10:
		_inv.current_offhand_slot = slot
	_character.off_hand_root.add_child(light)


func test_hotbar_switch_stow_extinguishes_a_lit_lantern() -> void:
	var light := await _spawn_lantern()
	_equip_mainhand_light(light)
	light.light()
	assert_true(light.is_lit, "precondition: the lantern is lit")

	_inv.set_mainhand_slot(1)

	_tolerate_light_harness_artifacts()
	assert_false(light.is_lit, "switching hotbar slots puts the lantern away extinguished")
	assert_false(light.firelight.visible, "the flame light is off after the stow")
	assert_null(_inv.current_mainhand_equipment, "the lantern left the hand")


func test_same_slot_toggle_holster_extinguishes_a_lit_lantern() -> void:
	var light := await _spawn_lantern()
	_equip_mainhand_light(light)
	light.light()
	assert_true(light.is_lit, "precondition: the lantern is lit")

	# Re-pressing the active slot toggles the item off: the de facto light
	# holster (inventory_controller only holsters weapon classes with H).
	_inv.set_mainhand_slot(0)

	_tolerate_light_harness_artifacts()
	assert_false(light.is_lit, "the holster toggle puts the lantern away extinguished")
	assert_false(light.firelight.visible, "the flame light is off after the holster")


func test_offhand_cycle_stow_extinguishes_a_lit_lantern() -> void:
	var light := await _spawn_lantern()
	_equip_offhand_light(light)
	light.light()
	assert_true(light.is_lit, "precondition: the lantern is lit")

	_inv.set_offhand_slot(2)

	_tolerate_light_harness_artifacts()
	assert_false(light.is_lit, "cycling the offhand slot puts the lantern away extinguished")
	assert_null(_inv.current_offhand_equipment, "the lantern left the offhand")


func test_reload_offhand_clear_extinguishes_and_returns_it_unlit() -> void:
	var light := await _spawn_lantern()
	_equip_offhand_light(light)
	light.light()
	assert_true(light.is_lit, "precondition: the lantern is lit")

	var gun : EquipmentItem = (load(WEBLEY_SCENE) as PackedScene).instantiate() as EquipmentItem
	add_child_autofree(gun)
	await get_tree().process_frame
	var body := _find_rigid_body(gun)
	if body != null:
		body.freeze = true
	gun.item_state = GlobalConsts.ItemState.EQUIPPED

	_character.play_reload_animation(gun)
	await get_tree().process_frame

	_tolerate_light_harness_artifacts()
	_tolerate_webley_uid_drift()
	assert_false(light.is_lit, "the reload offhand clear puts the light away extinguished")
	assert_false(light.firelight.visible, "the flame light is off during the reload")
	assert_null(_inv.current_offhand_equipment, "the offhand cleared for the reload")

	# Completion re-equips the same slot's item, now EXTINGUISHED (#644).
	gun.emit_signal("reload_stage_finished", 0)
	await get_tree().create_timer(0.7).timeout
	_tolerate_light_harness_artifacts()
	_tolerate_webley_uid_drift()
	assert_eq(_inv.current_offhand_equipment, light, "the light re-equips after the reload")
	assert_false(light.is_lit, "the re-equipped light stays extinguished")


func test_belt_hook_exemption_keeps_the_dark_lantern_burning() -> void:
	var light := await _spawn_lantern()
	_equip_mainhand_light(light)
	light.light()
	assert_true(light.is_lit, "precondition: the lantern burns under its open hood")

	# Belt-hook stow state: attach_to_belt sets is_in_belt and parents the
	# item to belt_position; humanoid rigs carry no belt node, so the attach
	# is flag-level here (same discipline as test_can_attach_reequip.gd).
	light.is_in_belt = true
	_inv.extinguish_stowed_light(light)

	_tolerate_light_harness_artifacts()
	assert_true(light.is_lit, "the belt-hook dark lantern keeps burning when stowed to the hook")
	assert_true(light.firelight.visible, "the hooded flame stays on")

	# Burn-state consistency: the belt-stowed lantern keeps consuming fuel.
	var fill_before : float = light.fuel.fill
	light._process(60.0)
	assert_true(light.is_lit, "still burning after simulated burn time")
	assert_lt(light.fuel.fill, fill_before,
		"the belt-hook lantern consumes fuel while belt-stowed")


func test_stowed_light_stops_consuming_fuel() -> void:
	var light := await _spawn_lantern()
	_equip_mainhand_light(light)
	light.light()

	_inv.set_mainhand_slot(1)

	_tolerate_light_harness_artifacts()
	assert_false(light.is_lit, "precondition: stowed extinguished")
	var fill_before : float = light.fuel.fill
	light._process(60.0)
	assert_almost_eq(light.fuel.fill, fill_before, 0.0001,
		"a stowed light does not consume fuel")


func test_drop_to_world_keeps_the_light_lit() -> void:
	# In-tree spawn so _ready builds the fuel state before lighting.
	var light := await _spawn_lantern_in_tree()
	light.light()
	assert_true(light.is_lit, "precondition: the lantern is lit")

	# The real state-machine drop transition (same idiom as
	# test_candle_drop_signals.gd); the drop flow routes items to the world
	# and never calls the stow seam.
	light._item_state_changed(GlobalConsts.ItemState.EQUIPPED, GlobalConsts.ItemState.DROPPED)

	_tolerate_light_harness_artifacts()
	assert_true(light.is_lit, "dropping to the world keeps the lantern lit")
	assert_true(light.firelight.visible, "the flame stays lit in the world")


func test_pickup_stow_extinguishes_when_no_hand_takes_it() -> void:
	var main_light := await _spawn_lantern()
	_equip_mainhand_light(main_light)
	var off_light := await _spawn_lantern()
	_equip_offhand_light(off_light)
	var candle := await _spawn_candle()
	candle.item_state = GlobalConsts.ItemState.DROPPED
	candle.light()
	assert_true(candle.is_lit, "precondition: the picked-up candle burns")

	var added : bool = _inv.add_item(candle)

	_tolerate_light_harness_artifacts()
	assert_true(added, "the candle was added to the inventory")
	assert_false(candle.is_lit,
		"a pickup that lands unequipped in a slot puts the candle away extinguished")
	assert_eq(_inv.hotbar[1], candle, "the candle sits in a hotbar slot, not in a hand")


func test_pickup_auto_equipped_to_a_hand_keeps_the_light_lit() -> void:
	var candle := await _spawn_candle()
	candle.item_state = GlobalConsts.ItemState.DROPPED
	candle.light()
	assert_true(candle.is_lit, "precondition: the picked-up candle burns")

	var added : bool = _inv.add_item(candle)

	_tolerate_light_harness_artifacts()
	assert_true(added, "the candle was added to the inventory")
	# Bare hands: place_in_hotbar routes the light to the offhand and equips
	# it (0.5 s internal delay), so the pickup is NOT a put-away.
	await get_tree().create_timer(0.7).timeout
	_tolerate_light_harness_artifacts()
	assert_eq(_inv.current_offhand_equipment, candle, "the candle auto-equipped to the bare offhand")
	assert_true(candle.is_lit, "a light taken into a hand stays lit")


func test_swap_hands_keeps_lights_burning() -> void:
	# A hand-to-hand swap is not a put-away: both lights stay burning.
	var main_light := await _spawn_lantern()
	_equip_mainhand_light(main_light)
	main_light.light()
	var off_light := await _spawn_lantern()
	_equip_offhand_light(off_light, 5)
	off_light.light()
	assert_true(main_light.is_lit and off_light.is_lit, "precondition: both lanterns burn")

	_inv.swap_hands()
	await get_tree().create_timer(0.7).timeout

	_tolerate_light_harness_artifacts()
	assert_eq(_inv.current_mainhand_equipment, off_light, "the offhand lantern took the main hand")
	assert_eq(_inv.current_offhand_equipment, main_light, "the mainhand lantern took the offhand")
	assert_true(main_light.is_lit, "the mainhand light moved hands still burning")
	assert_true(off_light.is_lit, "the offhand light moved hands still burning")


func _find_rigid_body(node : Node) -> RigidBody3D:
	if node is RigidBody3D:
		return node
	for child in node.get_children():
		var found := _find_rigid_body(child)
		if found != null:
			return found
	return null
