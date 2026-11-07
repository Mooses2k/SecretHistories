# Pins the candelabra hotbar-swap refill (owner ruling b, medical-reload
# baseline, fuel design doc section 6): one tap fills ONE spent candle slot
# to 1.0 by consuming one candle unit from a hotbar candle stack; the
# stack's representative node survives with units remaining, the node itself
# is consumed on its last unit (medical seam), a record-less candle is
# consumed the same way; a burned-out stub (fill 0.0) is not a wax source;
# refill never lights and never extinguishes; fresh wax clears the
# burned-out lockout. The candelabra script runs bare (its fuel states are
# built from number_of_candles alone, like test_light_burn_time), with the
# real candle scene as the wax source and the real candles_stack resource
# for the record.
extends GutTest

const CandelabraScript = preload("res://scenes/objects/pickable_items/equipment/tool/light-sources/candelabra/candelabra.gd")
const CandleScene = preload("res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle.tscn")
const InventoryScript = preload("res://scenes/characters/inventory.gd")
const CANDLE_PATH := "res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle.tscn"
const CANDLES_STACK := "res://resources/inventory/stackables/candles_stack.tres"


class StubCharacter extends Node:
	var inventory : Inventory


var _candles : Array[CandleItem] = []


func before_each() -> void:
	_candles.clear()


func after_each() -> void:
	for candle : CandleItem in _candles:
		if is_instance_valid(candle):
			candle.free()
	_candles.clear()


func _make_candelabra(fills : Array[float]) -> CandelabraItem:
	var candelabra: CandelabraItem = autofree(CandelabraScript.new())
	candelabra.number_of_candles = fills.size()
	candelabra._setup_candle_fuel()
	for i in range(fills.size()):
		candelabra.candle_fuel[i].fill = fills[i]
	return candelabra


func _make_inv() -> Inventory:
	var inv: Inventory = add_child_autofree(InventoryScript.new())
	return inv


func _holder(inv : Inventory, candelabra : CandelabraItem) -> StubCharacter:
	var character: StubCharacter = autofree(StubCharacter.new())
	character.inventory = inv
	candelabra.owner_character = character
	return character


## A hotbar candle stack like the record model produces: the representative
## node in the slot carries the record id, and the record holds the count.
func _make_candle_stack(inv : Inventory, slot : int, count : int, fill : float) -> CandleItem:
	var candle: CandleItem = CandleScene.instantiate()
	add_child(candle)
	_candles.append(candle)
	candle.fuel.fill = fill
	inv.hotbar[slot] = candle
	inv.add_to_stack_record(CANDLES_STACK, CANDLE_PATH, count)
	var record : StackableStackRecord = inv.records_for_type(CANDLES_STACK)[0]
	candle.stack_record_id = record.id
	return candle


func test_one_press_fills_one_spent_slot_to_full() -> void:
	var candelabra := _make_candelabra([0.0, 0.5, 1.0] as Array[float])
	var inv := _make_inv()
	_holder(inv, candelabra)
	_make_candle_stack(inv, 2, 2, 1.0)

	candelabra._use_reload()

	assert_almost_eq(candelabra.candle_fuel[0].fill, 1.0, 0.0001,
		"the first spent slot is topped to full")
	assert_almost_eq(candelabra.candle_fuel[1].fill, 0.5, 0.0001,
		"one press touches only one slot")


func test_one_press_consumes_one_unit_and_keeps_the_representative() -> void:
	var candelabra := _make_candelabra([0.0, 1.0, 1.0] as Array[float])
	var inv := _make_inv()
	_holder(inv, candelabra)
	var candle := _make_candle_stack(inv, 2, 3, 1.0)

	candelabra._use_reload()

	var record : StackableStackRecord = inv.get_stack_record(candle.stack_record_id)
	assert_eq(record.count, 2, "the stack record lost exactly one unit")
	assert_eq(inv.hotbar[2], candle,
		"the representative node stays in its slot with units remaining")
	assert_false(candle.is_queued_for_deletion(),
		"the representative node is not consumed while units remain")


func test_the_last_unit_consumes_the_node_like_the_medical_seam() -> void:
	var candelabra := _make_candelabra([0.0, 1.0, 1.0] as Array[float])
	var inv := _make_inv()
	_holder(inv, candelabra)
	var candle := _make_candle_stack(inv, 2, 1, 1.0)

	candelabra._use_reload()

	assert_null(inv.hotbar[2], "the consumed unit leaves the hotbar slot")
	assert_true(candle.is_queued_for_deletion(),
		"the last unit's node is consumed")
	assert_null(inv.get_stack_record(candle.stack_record_id),
		"the emptied record is destroyed")


func test_a_recordless_candle_is_consumed_the_same_way() -> void:
	var candelabra := _make_candelabra([0.0, 1.0, 1.0] as Array[float])
	var inv := _make_inv()
	_holder(inv, candelabra)
	var candle: CandleItem = CandleScene.instantiate()
	add_child(candle)
	_candles.append(candle)
	inv.hotbar[2] = candle

	candelabra._use_reload()

	assert_null(inv.hotbar[2], "the recordless unit leaves the hotbar slot")
	assert_true(candle.is_queued_for_deletion(),
		"a recordless candle node is consumed directly")


func test_refill_never_lights_or_extinguishes() -> void:
	var candelabra := _make_candelabra([0.0, 1.0, 1.0] as Array[float])
	var inv := _make_inv()
	_holder(inv, candelabra)
	_make_candle_stack(inv, 2, 2, 1.0)

	candelabra._use_reload()

	assert_false(candelabra.is_lit, "refilling an unlit candelabra must not light it")

	candelabra.candle_fuel[0].fill = 0.0
	candelabra.light()
	assert_true(candelabra.is_lit, "precondition: the candelabra is lit")
	_make_candle_stack(inv, 1, 2, 1.0)

	candelabra._use_reload()

	assert_true(candelabra.is_lit, "refilling a lit candelabra must not extinguish it")
	assert_false(candelabra.candle_lit[0],
		"the refilled slot does not auto-light")


func test_burned_out_stubs_are_not_wax_sources() -> void:
	var candelabra := _make_candelabra([0.0, 1.0, 1.0] as Array[float])
	var inv := _make_inv()
	_holder(inv, candelabra)
	var stub := _make_candle_stack(inv, 2, 2, 0.0)

	candelabra._use_reload()

	assert_almost_eq(candelabra.candle_fuel[0].fill, 0.0, 0.0001,
		"a fill 0.0 stub transfers nothing")
	assert_eq(inv.get_stack_record(stub.stack_record_id).count, 2,
		"the stub's units are untouched")


func test_no_spent_slot_is_a_noop() -> void:
	var candelabra := _make_candelabra([1.0, 1.0, 1.0] as Array[float])
	var inv := _make_inv()
	_holder(inv, candelabra)
	var candle := _make_candle_stack(inv, 2, 2, 1.0)

	candelabra._use_reload()

	assert_eq(inv.get_stack_record(candle.stack_record_id).count, 2,
		"a full candelabra consumes nothing")


func test_fresh_wax_clears_the_burned_out_lockout() -> void:
	var candelabra := _make_candelabra([0.0, 1.0, 1.0] as Array[float])
	var inv := _make_inv()
	_holder(inv, candelabra)
	_make_candle_stack(inv, 2, 2, 1.0)
	candelabra.is_depleted = true

	candelabra._use_reload()

	assert_false(candelabra.is_depleted,
		"fresh wax clears the burned-out lockout")
	candelabra.light()
	assert_true(candelabra.is_lit, "a refilled candelabra can be lit again")
