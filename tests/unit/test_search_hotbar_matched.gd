# Tests for the data-returning hotbar search seam in inventory.gd
# (Brooks audit 1.1): search_hotbar_matched returns (item, slot) pairs in hotbar
# slot order, returns an empty array when nothing matches, and is a pure read:
# calling it never mutates inventory state.
extends GutTest

const InventoryScript = preload("res://scenes/characters/inventory.gd")


func _make_inventory() -> Inventory:
	var inv = InventoryScript.new()
	add_child_autofree(inv)
	return inv


func _fill_hotbar(inv : Inventory) -> Array:
	# Three distinct stand-in items at slots 1, 4, 7. Slots 0 and 8 stay null
	# so the seam's null-skipping is exercised.
	var items := []
	for slot in [1, 4, 7]:
		var item = Node3D.new()
		item.name = "Item%d" % slot
		inv.hotbar[slot] = item
		items.append(item)
	return items


func _filter_matches_item_a(item) -> bool:
	return item.name == "Item1" or item.name == "Item7"


func test_returns_item_slot_pairs_for_a_matching_filter():
	var inv = _make_inventory()
	var items := _fill_hotbar(inv)
	var pairs = inv.search_hotbar_matched(_filter_matches_item_a)
	assert_eq(pairs.size(), 2, "only the two matching slots are reported")
	assert_eq(pairs[0][0], items[0], "first pair carries the slot 1 item")
	assert_eq(pairs[0][1], 1, "first pair carries the slot index 1")
	assert_eq(pairs[1][0], items[2], "second pair carries the slot 7 item")
	assert_eq(pairs[1][1], 7, "second pair carries the slot index 7")


func test_pairs_are_ordered_by_hotbar_slot():
	var inv = _make_inventory()
	var items := _fill_hotbar(inv)
	# A filter that matches everything, including the null-skipped gaps.
	var pairs = inv.search_hotbar_matched(func(_item): return true)
	assert_eq(pairs.size(), 3, "null slots are skipped, occupied ones reported")
	assert_lt(pairs[0][1], pairs[1][1], "slot order ascends")
	assert_lt(pairs[1][1], pairs[2][1], "slot order ascends")
	assert_eq(pairs[1][0], items[1], "middle match is the slot 4 item")


func test_empty_result_when_nothing_matches():
	var inv = _make_inventory()
	_fill_hotbar(inv)
	var pairs = inv.search_hotbar_matched(func(_item): return false)
	assert_eq(pairs, [], "no match means an empty result, not null")

	var empty_inv = _make_inventory()
	var pairs_empty = empty_inv.search_hotbar_matched(func(_item): return true)
	assert_eq(pairs_empty, [], "an empty hotbar yields an empty result")


func test_search_does_not_mutate_inventory_state():
	var inv = _make_inventory()
	var items := _fill_hotbar(inv)
	var first = inv.search_hotbar_matched(_filter_matches_item_a)
	var second = inv.search_hotbar_matched(_filter_matches_item_a)
	assert_eq(first, second, "repeated searches return identical data")
	for slot in range(inv.hotbar.size()):
		var expected = inv.hotbar[slot]
		inv.search_hotbar_matched(func(_item): return true)
		assert_eq(inv.hotbar[slot], expected, "hotbar slot %d is untouched by a search" % slot)
	assert_false(items[0].is_queued_for_deletion(), "matched items are not freed by the search")
