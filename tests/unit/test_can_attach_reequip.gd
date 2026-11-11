extends GutTest
## can_attach re-equip invariant: unequip clears the slot AND unparents the
## node from the hand, so any later equip can add_child it again with zero
## engine "already has a parent" errors. Pins the slot bookkeeping invariant
## directly and captures stderr through GUT's error tracker (the same channel
## test_reload_character_anim.gd uses to observe the pre-existing double-add).
## HumanoidCharacter rigs carry no belt_position node, so belt stow attaches
## are no-ops here; the is_in_belt branch is covered by the flag checks.

const HUMANOID_BASE_SCENE := "res://scenes/characters/humanoid_character_base/humanoid_character_base.tscn"
const DARK_LANTERN_SCENE := "res://scenes/objects/pickable_items/equipment/tool/light-sources/belt_clip_dark_lantern/dark_lantern.tscn"

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
	# test_reload_character_anim.gd): parenting it to an autofree wrapper
	# first would itself trip the "already has a parent" error the suite
	# guards against. The light_detection subtree is stripped and freed
	# immediately: its cone re-triangulates every frame and spams a benign
	# engine warning that pollutes the error tracker.
	var light : Node = (load(DARK_LANTERN_SCENE) as PackedScene).instantiate()
	autofree(light)
	light.is_in_belt = false
	for detection in _nodes_with_script_path(light, "light_detection"):
		# Freeing a matched parent frees its matched descendants too; the
		# validity guard skips those.
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


func _parent_error_count() -> int:
	var bad := 0
	for e in gut.error_tracker.get_current_test_errors():
		var text := String(e.code) + " " + String(e.rationale)
		if text.contains("already has a parent") or text.contains("p_child->data.parent"):
			bad += 1
	return bad


func _tolerate_light_harness_artifacts() -> void:
	# Harness-only engine noise from the belt-clip lantern's cone
	# re-triangulation; unrelated to the slot bookkeeping under test.
	for e in gut.error_tracker.get_current_test_errors():
		var text := String(e.code) + " " + String(e.rationale)
		if text.contains("Too few vertices per face"):
			e.handled = true


func _equip_offhand_light(light : Node) -> void:
	# Mirror a finished equip by hand (same harness shape as
	# test_reload_character_anim.gd): slot written directly, the setter's
	# delayed equip path is not under test here.
	_inv.hotbar[10] = light
	light.item_state = GlobalConsts.ItemState.EQUIPPED
	_inv.current_offhand_equipment = light
	_character.off_hand_root.add_child(light)


func test_offhand_unequip_clears_slot_and_unparents_can_attach_item() -> void:
	var light := await _spawn_lantern()
	_equip_offhand_light(light)
	_inv.unequip_offhand_item()
	_tolerate_light_harness_artifacts()
	assert_null(_inv.current_offhand_equipment, "slot cleared by unequip")
	assert_null(light.get_parent(), "can_attach node unparented with the slot")


func test_offhand_equip_unequip_cycles_have_zero_parent_errors() -> void:
	var light := await _spawn_lantern()
	for i in 3:
		_equip_offhand_light(light)
		await get_tree().create_timer(0.1).timeout
		_inv.unequip_offhand_item()
		assert_null(_inv.current_offhand_equipment, "slot cleared on cycle " + str(i))
		assert_null(light.get_parent(), "node unparented on cycle " + str(i))
	# Re-equip through the real equip_offhand_item() call (0.5 s internal
	# delay), the exact path the reload coordinator uses and the one that
	# used to double-add after its unequip.
	_inv.hotbar[10] = light
	_inv.equip_offhand_item()
	await get_tree().create_timer(0.7).timeout
	_tolerate_light_harness_artifacts()
	assert_eq(_inv.current_offhand_equipment, light, "re-equip succeeded after unequip")
	assert_eq(light.get_parent(), _character.off_hand_root, "node parented to the offhand root")
	assert_eq(_parent_error_count(), 0, "no already-has-a-parent engine errors")


func test_mainhand_equip_unequip_cycles_have_zero_parent_errors() -> void:
	var light := await _spawn_lantern()
	_inv.hotbar[0] = light
	light.item_state = GlobalConsts.ItemState.EQUIPPED
	_inv.current_mainhand_equipment = light
	_character.main_hand_root.add_child(light)
	_inv.unequip_mainhand_item()
	_tolerate_light_harness_artifacts()
	assert_null(_inv.current_mainhand_equipment, "mainhand slot cleared by unequip")
	assert_null(light.get_parent(), "mainhand can_attach node unparented")
	_inv.equip_mainhand_item()
	await get_tree().create_timer(0.7).timeout
	_tolerate_light_harness_artifacts()
	assert_eq(_inv.current_mainhand_equipment, light, "mainhand re-equip succeeded")
	assert_eq(light.get_parent(), _character.main_hand_root, "node parented to the main hand root")
	assert_eq(_parent_error_count(), 0, "no already-has-a-parent engine errors in main hand")


func test_is_in_belt_item_survives_unequip_parented() -> void:
	# The belt-stow semantic: a can_attach item flagged is_in_belt keeps its
	# parent through unequip (the belt holds it) and equip takes it back off.
	var light := await _spawn_lantern()
	_equip_offhand_light(light)
	light.is_in_belt = true
	_inv.unequip_offhand_item()
	_tolerate_light_harness_artifacts()
	assert_null(_inv.current_offhand_equipment, "slot cleared")
	assert_eq(light.get_parent(), _character.off_hand_root, "belt-flagged item stays parented")
	# Re-equip takes it off the belt onto the hand without a double-add.
	_inv.equip_offhand_item()
	await get_tree().create_timer(0.7).timeout
	_tolerate_light_harness_artifacts()
	assert_eq(_inv.current_offhand_equipment, light, "re-equip of a belt-flagged item succeeded")
	assert_eq(light.get_parent(), _character.off_hand_root, "node on the offhand root")
	assert_false(light.is_in_belt, "belt flag cleared by equip")
	assert_eq(_parent_error_count(), 0, "no already-has-a-parent engine errors from the belt path")


func test_attach_to_belt_is_a_safe_noop_without_a_belt_position() -> void:
	# HumanoidCharacter rigs have no belt node; the attach must not crash on
	# the missing belt_position key and must not disturb the item.
	var light := await _spawn_lantern()
	_equip_offhand_light(light)
	_inv.unequip_offhand_item()
	_tolerate_light_harness_artifacts()
	assert_null(light.get_parent(), "floating after unequip")
	_inv.attach_to_belt(light)
	_tolerate_light_harness_artifacts()
	assert_null(light.get_parent(), "no belt: the item keeps floating, no crash")
	assert_false(light.is_in_belt, "no belt: nothing was stowed")
	assert_eq(_parent_error_count(), 0, "no engine errors from the belt-less attach path")
