# Pins the freed-instance hotbar guard in the save inventory capture
# (debugger triage pass, lane A) and the Tier C stack format (T12/T13/T15):
# per-entry count/record_id/type_id, known_tiny_items persistence, the
# old-save count-1 fallback, and the load-end encumbrance recompute.
# The capture used to type its slot read as EquipmentItem BEFORE the
# is_instance_valid guard: assigning a freed instance to a typed variable
# throws, the whole capture aborted, and the saved entities/player.json
# ended up with "inventory": {} (verified on disk in the 2026-11-05
# capture, 2/2 manual saves). The fix reads the slot untyped, guards
# before any typed assign, and skips only the bad slot. The mirror in the
# load path (_apply_cultist_inventory clear loop) is pinned too. Candle
# scenes are lightweight, so the real one is used.
extends GutTest

const CandleScene = preload("res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle.tscn")
const CANDLE_PATH := "res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle.tscn"
const DAGGER_SCENE := "res://scenes/objects/pickable_items/equipment/melee/dagger/dagger.tscn"
const DAGGERS_STACK := "res://resources/inventory/stackables/daggers_stack.tres"
const SPYGLASS_RESOURCE := "res://resources/tiny_items/spyglass.tres"


func _make_inventory() -> Inventory:
	var inv: Inventory = add_child_autofree(Inventory.new())
	return inv


func _make_candle() -> EquipmentItem:
	var candle: EquipmentItem = add_child_autofree(CandleScene.instantiate()) as EquipmentItem
	return candle


## A dagger scene instance placed with its own count-1 record, like the T2/T3
## pickup flow; the count is then topped up so the record holds real units.
func _make_dagger_with_count(inv: Inventory, count: int) -> EquipmentItem:
	var dagger: EquipmentItem = (load(DAGGER_SCENE) as PackedScene).instantiate() as EquipmentItem
	add_child_autofree(dagger)
	var slot: int = inv.place_in_hotbar(dagger)
	assert(slot != -1, "precondition: the dagger was placed")
	if count > 1:
		inv.add_to_stack_record(DAGGERS_STACK, DAGGER_SCENE, count - 1)
	return dagger


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


func test_cultist_loadout_clear_resets_stack_records_and_id_counter():
	var cultist: Node = autofree(Node.new())
	var inv: Inventory = Inventory.new()
	inv.name = "Inventory"
	cultist.add_child(inv)
	add_child_autofree(cultist)
	assert_true(inv.add_to_stack_record(DAGGERS_STACK, DAGGER_SCENE, 2),
		"precondition: a record exists before the clear")

	SaveManager._apply_cultist_inventory(cultist, {})

	assert_eq(inv.stack_records.size(), 0, "T15: the record array is cleared with the loadout")
	assert_eq(inv._next_stack_record_id, 0, "T15: the id counter restarts")


func test_capture_records_stack_count_and_type():
	var inv: Inventory = _make_inventory()
	var dagger: EquipmentItem = _make_dagger_with_count(inv, 2)

	var captured: Dictionary = SaveManager._capture_inventory(inv)

	var hotbar: Array = captured["hotbar"]
	assert_eq(hotbar.size(), 1, "the dagger entry is captured")
	var entry: Dictionary = hotbar[0]
	assert_eq(int(entry["count"]), 2, "T12: the record count is captured, not 1")
	assert_eq(int(entry["record_id"]), dagger.stack_record_id, "T12: the record id is captured")
	assert_eq(str(entry["type_id"]), DAGGERS_STACK, "T12: the type id is the record's type")


func test_capture_records_known_tiny_items():
	var inv: Inventory = _make_inventory()
	inv.known_tiny_items[load(SPYGLASS_RESOURCE)] = true

	var captured: Dictionary = SaveManager._capture_inventory(inv)

	assert_eq(captured["known_tiny_items"], {SPYGLASS_RESOURCE: true},
		"T12: the #661 awareness set is captured as resource paths")


func test_restore_writes_saved_count_and_recomputes_encumbrance():
	var inv: Inventory = _make_inventory()
	inv.encumbrance = 999.0   # stale pre-load value; the recompute must overwrite it

	SaveManager._apply_inventory(inv, {
		"hotbar": [{"path": DAGGER_SCENE, "slot": 0, "count": 2, "record_id": 7,
			"type_id": DAGGERS_STACK}],
	})

	var dagger: EquipmentItem = inv.hotbar[0] as EquipmentItem
	assert_not_null(dagger, "the stack representative is restored")
	assert_eq(dagger.stack_record_id, 0, "the placed representative carries its fresh record")
	assert_eq(inv.get_stack_record(dagger.stack_record_id).count, 2,
		"T13: the saved count is restored onto the record")
	assert_eq(inv.encumbrance, 0.0,
		"T13: the load ends with a deterministic recount (daggers weigh 0), not the stale value")


func test_restore_two_entries_of_one_type_stay_separate_records():
	var inv: Inventory = _make_inventory()

	SaveManager._apply_inventory(inv, {
		"hotbar": [
			{"path": DAGGER_SCENE, "slot": 0, "count": 2, "record_id": 7, "type_id": DAGGERS_STACK},
			{"path": DAGGER_SCENE, "slot": 1, "count": 2, "record_id": 8, "type_id": DAGGERS_STACK},
		],
	})

	assert_eq(inv.stack_records.size(), 2,
		"T13: the pickup merge must not absorb a later same-type entry during restore")
	for record: StackableStackRecord in inv.stack_records:
		assert_eq(record.count, 2, "each restored record holds its own saved count")


func test_restore_old_save_entry_falls_back_to_count_1():
	var inv: Inventory = _make_inventory()

	SaveManager._apply_inventory(inv, {
		"hotbar": [{"path": DAGGER_SCENE, "slot": 0}],
	})

	var dagger: EquipmentItem = inv.hotbar[0] as EquipmentItem
	assert_not_null(dagger, "the old-save entry is restored without loss")
	assert_eq(inv.get_stack_record(dagger.stack_record_id).count, 1,
		"T13 fallback: a missing count means 1 (stacks collapse to single units)")
	assert_eq(inv.encumbrance, 0.0, "encumbrance recomputes for the collapsed inventory")


func test_restore_known_tiny_items_survive_at_zero_count():
	var inv: Inventory = _make_inventory()

	SaveManager._apply_inventory(inv, {
		"hotbar": [],
		"known_tiny_items": {SPYGLASS_RESOURCE: true},
	})

	assert_eq(inv.tiny_items.size(), 0, "no tiny amount was saved, none is restored")
	assert_eq(inv.known_tiny_items.size(), 1,
		"T12: the awareness set survives save/load even with the type spent to zero")
