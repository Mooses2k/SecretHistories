# Pins the disposable-light drop-timer repairs (debugger triage lane B):
#   1. stop_light_timer() must not clobber burn_time from a stopped or
#      never-started timer (reading time_left there returned 0, so a dropped
#      never-lit candle/torch lost its whole 3600 s / 600 s budget).
#   2. item_drop() must never hand Timer.set_wait_time a value <= 0
#      ("Time should be greater than zero" engine error, 2x per throw).
#   3. item_drop() must start the burn timer only when the item is inside
#      the scene tree: inventory._drop_item sets DROPPED before the item is
#      re-added to the level ("not inside the scene tree" engine error).
# Real lightweight scenes are used (candle 37 KB, torch similar); the throw
# sequence mirrors inventory._drop_item plus player_controller.throw_object,
# which together produce the two real DROPPED transitions of one throw.
extends GutTest

const CandleScene = preload("res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle.tscn")
const TorchScene = preload("res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/torch/torch.tscn")


func _make(scene : PackedScene):
	var item = scene.instantiate()
	item.life_percentage_lose = 0.0
	return add_child_autofree(item)


func test_never_lit_candle_drop_keeps_burn_time():
	var candle = _make(CandleScene)

	candle.item_drop()

	assert_eq(candle.burn_time, 3600.0,
		"a dropped never-lit candle must keep its full burn budget")
	assert_eq(candle.light_timer.wait_time, 3600.0,
		"the drop timer must be set from the preserved burn budget")


func test_never_lit_torch_drop_keeps_burn_time():
	var torch = _make(TorchScene)

	torch.item_drop()

	assert_eq(torch.burn_time, 600.0,
		"a dropped never-lit torch must keep its full burn budget")
	assert_eq(torch.light_timer.wait_time, 600.0,
		"the drop timer must be set from the preserved burn budget")


func test_item_drop_clamps_wait_time_positive_candle():
	var candle = _make(CandleScene)
	candle.light()
	candle.unlight()
	candle.burn_time = 0.0  # a genuinely non-positive remainder

	candle.item_drop()

	assert_almost_eq(candle.light_timer.wait_time, 0.1, 0.001,
		"a non-positive remainder must clamp to the 0.1 s floor, never error")


func test_item_drop_clamps_wait_time_positive_torch():
	var torch = _make(TorchScene)
	torch.light()
	torch.unlight()
	torch.burn_time = 0.0  # a genuinely non-positive remainder

	torch.item_drop()

	assert_almost_eq(torch.light_timer.wait_time, 0.1, 0.001,
		"a non-positive remainder must clamp to the 0.1 s floor, never error")


func test_drop_out_of_tree_defers_timer_start_candle():
	var candle = _make(CandleScene)
	candle.light()

	# inventory._drop_item(): the state change fires while the item is
	# between the unequip removal and the re-add to the level.
	remove_child(candle)
	candle._item_state_changed(GlobalConsts.ItemState.EQUIPPED, GlobalConsts.ItemState.DROPPED)
	add_child(candle)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(candle.is_lit, "the drop must not extinguish a lit candle")
	assert_gt(candle.light_timer.time_left, 0.0,
		"the burn timer must be running after the item re-enters the tree")


func test_drop_out_of_tree_defers_timer_start_torch():
	var torch = _make(TorchScene)
	torch.light()

	remove_child(torch)
	torch._item_state_changed(GlobalConsts.ItemState.EQUIPPED, GlobalConsts.ItemState.DROPPED)
	add_child(torch)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(torch.is_lit, "the drop must not extinguish a lit torch")
	assert_gt(torch.light_timer.time_left, 0.0,
		"the burn timer must be running after the item re-enters the tree")


func test_burn_timer_timeout_depletes_candle():
	var candle = _make(CandleScene)
	candle.light()

	# The BurnTime timeout wiring lives in candle.tscn; the emitted signal
	# must run the depletion chain on its own.
	candle.light_timer.timeout.emit()

	assert_true(candle.is_depleted, "the burn timer timeout must deplete the candle")
	assert_false(candle.is_lit, "the burn timer timeout must extinguish the candle")


func test_burn_timer_timeout_depletes_torch():
	var torch = _make(TorchScene)
	torch.light()

	torch.light_timer.timeout.emit()

	assert_true(torch.is_depleted, "the burn timer timeout must deplete the torch")
	assert_false(torch.is_lit, "the burn timer timeout must extinguish the torch")
