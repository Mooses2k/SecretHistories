# Pins the candle/candelabra declared-signal drop path (Brooks Wave 1 row 7,
# audit 4.4): dropping a lit candle applies the burn_time penalty EXACTLY ONCE
# through the declared item_is_dropped signal (the old direct item_drop() call
# on top of the signal double-applied it), and candelabra drops emit its
# DECLARED item_dropped signal (the old emit used the undeclared
# "item_is_dropped", which silently did nothing).
# The real candle scene is lightweight (37 KB) so it is loaded for the candle
# side. The candelabra scene embeds ~750 KB of mesh data, so the candelabra
# side uses a script subclass double and pins the connect/emit wiring
# semantics per the audit's evidence. The double runs with
# number_of_candles = 1 because the candle 2/3 branch starts live Timer2 and
# Timer3 nodes, which cannot run outside the scene tree.
extends GutTest

const CandleScene = preload("res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle.tscn")


class CandelabraDouble extends "res://scenes/objects/pickable_items/equipment/tool/light-sources/candelabra/candelabra.gd":
	var drop_calls : Array = []

	func item_drop():
		drop_calls.append("item_drop")


func _make_candle():
	var candle = CandleScene.instantiate()
	return add_child_autofree(candle)


func _make_candelabra_double():
	var candelabra = autofree(CandelabraDouble.new())
	candelabra.number_of_candles = 1
	candelabra.life_percentage_lose = 0.5
	return candelabra


func test_item_is_dropped_signal_is_wired_to_item_drop():
	var candle = _make_candle()

	assert_true(candle.is_connected("item_is_dropped", Callable(candle, "item_drop")),
		"the declared drop signal must be wired to the base item_drop() penalty")


func test_one_drop_applies_burn_penalty_exactly_once():
	var candle = _make_candle()
	candle.life_percentage_lose = 0.5
	candle.light()
	watch_signals(candle)

	# The real state machine reaches this from the DROPPED transition.
	candle._item_state_changed(GlobalConsts.ItemState.EQUIPPED, GlobalConsts.ItemState.DROPPED)

	assert_signal_emitted(candle, "item_is_dropped")
	assert_signal_emit_count(candle, "item_is_dropped", 1, "one drop emits the drop signal once")
	# Fuel-model update (expected contract change per the fuel design): the
	# penalty now applies to the fill, and fill only depletes while lit, so a
	# drop of a full candle lands on exactly 0.5. A double-apply regression
	# would land on 0.25, a lost penalty on 1.0.
	assert_almost_eq(candle.fuel.fill, 0.5, 0.001,
		"the drop penalty must be applied exactly once to the fuel fill")


func test_candelabra_emits_declared_item_dropped_signal_on_drop():
	var candelabra = _make_candelabra_double()

	assert_true(candelabra.has_signal("item_dropped"), "item_dropped must be a declared signal")
	assert_false(candelabra.has_signal("item_is_dropped"), "the undeclared legacy signal name must not exist")
	watch_signals(candelabra)

	candelabra._item_state_changed(GlobalConsts.ItemState.EQUIPPED, GlobalConsts.ItemState.DROPPED)

	assert_signal_emit_count(candelabra, "item_dropped", 1,
		"the drop transition must emit the DECLARED signal name")


func test_light_dropped_applies_base_penalty_first():
	var candelabra = _make_candelabra_double()

	candelabra.light_dropped()

	assert_eq(candelabra.drop_calls, ["item_drop"],
		"the base candle 1 penalty must be applied through light_dropped (candles 2/3 need live timers, out of scope here)")
