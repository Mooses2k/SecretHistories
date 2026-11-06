# Pins the freed-instance hotbar guard in the save inventory capture
# (debugger triage pass, lane A). The capture used to type its slot read as
# EquipmentItem BEFORE the is_instance_valid guard: assigning a freed
# instance to a typed variable throws, the whole capture aborted, and the
# saved entities/player.json ended up with "inventory": {} (verified on
# disk in the 2026-11-05 capture, 2/2 manual saves). The fix reads the slot
# untyped, guards before any typed assign, and skips only the bad slot.
# The mirror in the load path (_apply_cultist_inventory clear loop) is
# pinned too. Candle scenes are lightweight, so the real one is used.
extends GutTest

const CandleScene = preload("res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle.tscn")
const CANDLE_PATH := "res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle.tscn"


func _make_inventory() -> Inventory:
	var inv: Inventory = add_child_autofree(Inventory.new())
	return inv


func _make_candle() -> EquipmentItem:
	var candle: EquipmentItem = add_child_autofree(CandleScene.instantiate()) as EquipmentItem
	return candle


func _freed_slot_reference(inv: Inventory, slot: int) -> void:
	# Put a real item in the slot, then free it while the slot still holds
	# the reference (the observed in-game state, e.g. a consumed item freed
	# by its own script without clearing the slot).
	var doomed: EquipmentItem = CandleScene.instantiate() as EquipmentItem
	inv.hotbar[slot] = doomed
	doomed.free()


func test_capture_skips_freed_slot_and_keeps_healthy_slots():
	var inv: Inventory = _make_inventory()
	inv.hotbar[0] = _make_candle()
	_freed_slot_reference(inv, 1)
	inv.hotbar[2] = _make_candle()

	var captured: Variant = SaveManager._capture_inventory(inv)

	assert_not_null(captured,
		"capture must not abort: pre-fix the typed slot assign threw on the freed slot")
	var hotbar: Array = (captured as Dictionary)["hotbar"]
	assert_eq(hotbar.size(), 2, "one bad slot must not blank the rest of the inventory")
	var slots: Array = hotbar.map(func(entry): return int(entry["slot"]))
	assert_has(slots, 0, "the healthy slot before the freed one must be captured")
	assert_has(slots, 2, "the healthy slot after the freed one must be captured")
	assert_does_not_have(slots, 1, "the freed slot must not produce an entry")
	for entry: Variant in hotbar:
		assert_eq(str((entry as Dictionary)["path"]), CANDLE_PATH, "captured path must match the item scene")


func test_capture_with_only_healthy_items_records_every_slot():
	var inv: Inventory = _make_inventory()
	inv.hotbar[0] = _make_candle()
	inv.hotbar[2] = _make_candle()
	inv.hotbar[4] = _make_candle()

	var captured: Variant = SaveManager._capture_inventory(inv)

	var hotbar: Array = (captured as Dictionary)["hotbar"]
	assert_eq(hotbar.size(), 3, "every populated healthy slot must be captured")
	var slots: Array = hotbar.map(func(entry): return int(entry["slot"]))
	assert_eq(slots, [0, 2, 4], "captured slots must match the populated hotbar slots")


func test_capture_covers_tiny_items_and_keychain():
	var inv: Inventory = _make_inventory()
	inv.hotbar[0] = _make_candle()
	inv.keychain[3] = 2

	var captured: Variant = SaveManager._capture_inventory(inv)

	assert_eq((captured as Dictionary)["keychain"], {"3": 2},
		"keychain capture must survive alongside the hotbar capture")


func test_cultist_loadout_clear_skips_freed_slot_without_aborting():
	var cultist: Node = autofree(Node.new())
	var inv: Inventory = Inventory.new()
	inv.name = "Inventory"
	cultist.add_child(inv)
	add_child_autofree(cultist)
	inv.hotbar[0] = _make_candle()
	_freed_slot_reference(inv, 1)

	SaveManager._apply_cultist_inventory(cultist, {})

	for slot in inv.hotbar.size():
		assert_null(inv.hotbar[slot], "the clear loop must null every slot, freed references included")
	assert_null(inv.bulky_equipment, "bulky equipment must be cleared")
