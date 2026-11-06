# Pins the LIVE hotbar highlight logic: hotbar_slot.gd update_equipped_status
# and its signal-driven wiring (the retired test_hotbar_highlight.gd pinned
# hotbar.gd, an orphaned script attached to nothing since 2022; see
# docs/research/hotbar-architecture-explained.md sections 2, 5, 7).
# Semantics pinned, per hotbar_slot.gd as authored on dev4:
#   - A normal slot row is lit (equipped color) on the MainHandIndicator only
#     while index == inventory.current_mainhand_slot AND
#     inventory.bulky_equipment == null (the and-condition that disambiguates
#     the Bulky row and the "1" row, which both carry index 0).
#   - The OffHandIndicator is lit while index == current_offhand_slot and the
#     slot's item is empty or SIZE_SMALL; a two-handed (SIZE_MEDIUM) item in
#     the slot can never show as offhand-equipped (can_not color).
#   - The is_bulky row is lit only while inventory.bulky_equipment == its item,
#     hides its indicators, and labels itself "Bulky"; it reacts to the
#     bulky_item_changed signal.
#   - Hand-slot updates arrive through the inventory signals
#     mainhand_slot_changed / offhand_slot_changed (previous, current) and
#     reach ONLY the rows whose index equals previous or current; other rows
#     are left untouched.
#   - Index 10 is the hands-free sentinel row (hotbar[10] never holds an
#     item): it lights when a hand cursor points at 10, testable off-tree.
# The slot script is instantiated off-tree with manually built minimal child
# nodes (the @onready paths), a stubbed inventory double emitting the real
# signal names, and the exported modulate colors set to distinct values, so
# the update paths run exactly as the shipped wiring runs them.
extends GutTest

const HotbarSlotScript = preload("res://scenes/ui/hotbar/hotbar_slot.gd")
const EquipmentScript = preload("res://scenes/objects/pickable_items/equipment/equipment_item.gd")

const EQUIPPED_COLOR := Color(1.0, 0.0, 0.0)
const CAN_EQUIP_COLOR := Color(0.0, 1.0, 0.0)
const CAN_NOT_EQUIP_COLOR := Color(0.0, 0.0, 1.0)
const SENTINEL_COLOR := Color(0.5, 0.5, 0.5)


class InventoryDouble extends Node:
	signal hotbar_changed(slot)
	signal bulky_item_changed()
	signal tiny_item_changed(tiny_item, previous, current)
	signal mainhand_slot_changed(previous, current)
	signal offhand_slot_changed(previous, current)
	signal inventory_changed()
	signal player_died()

	var hotbar : Array = []
	var bulky_equipment = null
	var current_mainhand_slot : int = 0
	var current_offhand_slot : int = 0
	var tiny_items : Dictionary = {}


class LabelStub extends Label:
	pass


class IndicatorStub extends Control:
	pass


func _make_inventory_double() -> InventoryDouble:
	var inv = autofree(InventoryDouble.new())
	inv.hotbar.resize(11)
	return inv


func _make_slot(slot_index : int, bulky : bool = false):
	var slot = autofree(HotbarSlotScript.new())
	slot.name = "Slot%d" % slot_index
	slot.index = slot_index
	slot.is_bulky = bulky
	slot.can_equip_modulate = CAN_EQUIP_COLOR
	slot.equipped_modulate = EQUIPPED_COLOR
	slot.can_not_equip_modulate = CAN_NOT_EQUIP_COLOR
	# Minimal child tree for the @onready paths the update methods touch.
	# The slot is instantiated off-tree, so _ready never runs and the @onready
	# members are assigned here explicitly; child nodes are plain new() and
	# free with the slot itself.
	var item_info := Control.new()
	item_info.name = "ItemInfo"
	slot.add_child(item_info)
	var hbox := HBoxContainer.new()
	hbox.name = "HBoxContainer"
	item_info.add_child(hbox)
	var ammo_label := Label.new()
	ammo_label.name = "AmmoCount"
	hbox.add_child(ammo_label)
	var item_name_label := Label.new()
	item_name_label.name = "ItemName"
	hbox.add_child(item_name_label)
	slot.ammo_count = ammo_label
	slot.item_name_label = item_name_label
	var use_indicators := Control.new()
	use_indicators.name = "UseIndicators"
	slot.add_child(use_indicators)
	var indicator_box := HBoxContainer.new()
	indicator_box.name = "HBoxContainer"
	use_indicators.add_child(indicator_box)
	var main_hand := IndicatorStub.new()
	main_hand.name = "MainHandIndicator"
	indicator_box.add_child(main_hand)
	var off_hand := IndicatorStub.new()
	off_hand.name = "OffHandIndicator"
	indicator_box.add_child(off_hand)
	var slot_number := Control.new()
	slot_number.name = "SlotNumber"
	slot.add_child(slot_number)
	var number_box := HBoxContainer.new()
	number_box.name = "HBoxContainer"
	slot_number.add_child(number_box)
	var number_label := Label.new()
	number_label.name = "SlotNumber"
	number_box.add_child(number_label)
	return slot


func _make_equipment(size : GlobalConsts.ItemSize):
	var item = autofree(EquipmentScript.new())
	item.item_size = size
	return item


func _main_indicator(slot) -> Color:
	return slot.get_node("UseIndicators/HBoxContainer/MainHandIndicator").modulate


func _off_indicator(slot) -> Color:
	return slot.get_node("UseIndicators/HBoxContainer/OffHandIndicator").modulate


func test_current_mainhand_slot_row_shows_equipped_and_other_hand_can_equip():
	var inv = _make_inventory_double()
	inv.current_mainhand_slot = 2
	var slot = _make_slot(2)
	slot.inventory = inv

	assert_eq(_main_indicator(slot), EQUIPPED_COLOR, "mainhand cursor slot row is lit")
	assert_eq(_off_indicator(slot), CAN_EQUIP_COLOR, "the same row is still offhand-equippable")


func test_empty_non_current_row_is_not_lit_on_either_hand():
	var inv = _make_inventory_double()
	var slot = _make_slot(5)
	slot.inventory = inv

	assert_eq(_main_indicator(slot), CAN_EQUIP_COLOR, "empty non-current row: mainhand shows can-equip, not equipped")
	assert_eq(_off_indicator(slot), CAN_EQUIP_COLOR, "empty non-current row: offhand shows can-equip, not equipped")


func test_offhand_indicator_rejects_a_two_handed_item():
	var inv = _make_inventory_double()
	inv.current_mainhand_slot = 2
	var slot = _make_slot(2)
	slot.inventory = inv
	slot.item = _make_equipment(GlobalConsts.ItemSize.SIZE_MEDIUM)

	assert_eq(_main_indicator(slot), EQUIPPED_COLOR, "mainhand lit by cursor position")
	assert_eq(_off_indicator(slot), CAN_NOT_EQUIP_COLOR, "a medium item can never be offhand-equipped")


func test_offhand_row_lights_while_cursor_is_on_it():
	var inv = _make_inventory_double()
	inv.current_offhand_slot = 3
	var slot = _make_slot(3)
	slot.inventory = inv

	assert_eq(_off_indicator(slot), EQUIPPED_COLOR, "offhand cursor slot row is lit")
	assert_eq(_main_indicator(slot), CAN_EQUIP_COLOR, "mainhand cursor is elsewhere, row shows can-equip")


func test_normal_index_zero_row_is_NOT_lit_while_bulky_equipment_is_held():
	# The disambiguation: the Bulky display row and the "1" row both carry
	# index 0. The "1" row may only light when NO bulky equipment is held.
	var inv = _make_inventory_double()
	inv.current_mainhand_slot = 0
	inv.bulky_equipment = _make_equipment(GlobalConsts.ItemSize.SIZE_BULKY)
	var slot = _make_slot(0)
	slot.inventory = inv

	assert_eq(_main_indicator(slot), CAN_EQUIP_COLOR,
		"index 0 row must not show equipped while bulky_equipment is non-null")


func test_bulky_row_lights_only_while_bulky_equipment_is_held():
	var inv = _make_inventory_double()
	var bulky_item = _make_equipment(GlobalConsts.ItemSize.SIZE_BULKY)
	inv.bulky_equipment = bulky_item
	var slot = _make_slot(0, true)
	slot.inventory = inv

	assert_eq(_main_indicator(slot), EQUIPPED_COLOR, "bulky row mainhand indicator lit while held")
	# Authored quirk pinned as-is: update_mainhand_indicator clears
	# is_equipped_offhand whenever the mainhand is equipped, so the bulky
	# row's OffHandIndicator falls back to the can-equip color even though
	# is_equipped_offhand was set true in update_equipped_status.
	assert_eq(_off_indicator(slot), CAN_EQUIP_COLOR, "bulky row offhand indicator falls back to can-equip (authored flag clear)")
	assert_false(slot.get_node("UseIndicators").visible, "bulky row hides its use indicators")
	assert_eq(slot.get_node("SlotNumber/HBoxContainer/SlotNumber").text, "Bulky", "bulky row labels itself Bulky")

	inv.bulky_equipment = null
	inv.bulky_item_changed.emit()

	assert_eq(_main_indicator(slot), CAN_EQUIP_COLOR, "bulky row unlights through the bulky_item_changed signal")


func test_bulky_row_appears_and_disappears_through_the_signal():
	var inv = _make_inventory_double()
	var slot = _make_slot(0, true)
	slot.inventory = inv
	assert_false(slot.visible, "bulky row starts hidden with nothing equipped")

	inv.bulky_equipment = _make_equipment(GlobalConsts.ItemSize.SIZE_BULKY)
	inv.bulky_item_changed.emit()

	assert_true(slot.visible, "bulky row becomes visible when a bulky item is equipped")


func test_mainhand_slot_changed_signal_updates_only_previous_or_current_rows():
	var inv = _make_inventory_double()
	inv.current_mainhand_slot = 0
	var target = _make_slot(2)
	target.inventory = inv
	var untouched = _make_slot(5)
	untouched.inventory = inv
	untouched.get_node("UseIndicators/HBoxContainer/MainHandIndicator").modulate = SENTINEL_COLOR

	# The real inventory setter moves the cursor first, then the signal notifies.
	inv.current_mainhand_slot = 2
	inv.mainhand_slot_changed.emit(0, 2)

	assert_eq(_main_indicator(target), EQUIPPED_COLOR, "current row lit via the mainhand_slot_changed signal")
	assert_eq(untouched.get_node("UseIndicators/HBoxContainer/MainHandIndicator").modulate, SENTINEL_COLOR,
		"rows whose index is neither previous nor current are never updated by the signal")


func test_offhand_slot_changed_signal_lights_the_hands_sentinel_row():
	# Index 10 is the hands-free sentinel: hotbar[10] never holds an item, but
	# the hand cursors legitimately point at it. Its update path is the same
	# signal-driven path as any other row, exercised off-tree here.
	var inv = _make_inventory_double()
	var hands_row = _make_slot(10)
	hands_row.inventory = inv

	# The real inventory setter moves the cursor first, then the signal notifies.
	inv.current_offhand_slot = 10
	inv.offhand_slot_changed.emit(2, 10)

	assert_eq(_off_indicator(hands_row), EQUIPPED_COLOR, "hands-free sentinel row lights when the offhand cursor reaches 10")
	assert_eq(_main_indicator(hands_row), CAN_EQUIP_COLOR, "mainhand cursor not at 10, sentinel row shows can-equip")
