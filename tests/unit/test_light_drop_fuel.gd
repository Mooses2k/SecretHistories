# Pins the fuel-model drop and depletion behavior on the candle family,
# replacing the pre-fuel drop-timer pins (CONTRACT CHANGE, expected per the
# fuel design: docs/plans/light-source-fuel-design.md section 9 step 4 replaces
# the burn timers with fill depletion). What must NOT change:
#   1. A dropped never-lit light keeps its whole fuel budget.
#   2. item_drop() applies the life_percentage_lose penalty exactly once.
#   3. Dropping a lit light must not extinguish it.
#   4. Burning out self-extinguishes and marks the light depleted.
#   5. Throw-away checks keep their authored 3.x forms (candle: linear
#      velocity, torch: angular velocity).
# Real lightweight scenes are used (candle 37 KB, torch similar).
extends GutTest

const CandleScene = preload("res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle.tscn")
const TorchScene = preload("res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/torch/torch.tscn")


func _make(scene : PackedScene):
	var item = scene.instantiate()
	item.life_percentage_lose = 0.0
	return add_child_autofree(item)


func test_never_lit_candle_drop_keeps_fuel():
	var candle = _make(CandleScene)

	candle.item_drop()

	assert_almost_eq(candle.fuel.fill, 1.0, 0.0001,
		"a dropped never-lit candle must keep its full fuel budget")


func test_never_lit_torch_drop_keeps_fuel():
	var torch = _make(TorchScene)

	torch.item_drop()

	assert_almost_eq(torch.fuel.fill, 1.0, 0.0001,
		"a dropped never-lit torch must keep its full fuel budget")


func test_one_candle_drop_applies_penalty_exactly_once():
	var candle = _make(CandleScene)
	candle.life_percentage_lose = 0.5

	candle.item_drop()

	assert_almost_eq(candle.fuel.fill, 0.5, 0.0001,
		"one drop halves the fill exactly once")


func test_one_torch_drop_applies_penalty_exactly_once():
	var torch = _make(TorchScene)
	torch.life_percentage_lose = 0.5

	torch.item_drop()

	assert_almost_eq(torch.fuel.fill, 0.5, 0.0001,
		"one drop halves the fill exactly once")


func test_dropping_a_lit_candle_does_not_extinguish_it():
	var candle = _make(CandleScene)
	candle.light()

	candle.item_drop()

	assert_true(candle.is_lit, "the drop must not extinguish a lit candle")


func test_dropping_a_lit_torch_does_not_extinguish_it():
	var torch = _make(TorchScene)
	torch.light()

	torch.item_drop()

	assert_true(torch.is_lit, "the drop must not extinguish a lit torch")


func test_candle_throw_may_blow_out():
	var candle = _make(CandleScene)
	candle.prob_going_out = 1.0
	candle.light()
	candle.linear_velocity = Vector3(1.0, 0.0, 0.0)

	candle.item_drop()

	assert_false(candle.is_lit, "a 100 percent blow-out chance must extinguish a thrown candle")


func test_torch_throw_may_blow_out():
	var torch = _make(TorchScene)
	torch.prob_going_out = 1.0
	torch.light()
	torch.angular_velocity = Vector3(0.0, 6.0, 0.0)

	torch.item_drop()

	assert_false(torch.is_lit, "a 100 percent blow-out chance must extinguish a thrown torch")


func test_burning_out_depletes_and_extinguishes_candle():
	var candle = _make(CandleScene)
	candle.fuel.set_fuel(FuelSource.FuelKind.WAX, 1.0)  # 1 s budget
	candle.light()

	# One full second of _process consumes the whole budget.
	candle._process(1.0)

	assert_false(candle.is_lit, "burning out must extinguish the candle")
	assert_almost_eq(candle.fuel.fill, 0.0, 0.0001, "burning out empties the fill")


func test_burning_out_depletes_and_extinguishes_torch():
	var torch = _make(TorchScene)
	torch.fuel.set_fuel(FuelSource.FuelKind.WAX, 1.0)
	torch.light()

	torch._process(1.0)

	assert_false(torch.is_lit, "burning out must extinguish the torch")
	assert_almost_eq(torch.fuel.fill, 0.0, 0.0001, "burning out empties the fill")


func test_unlit_light_does_not_deplete():
	var candle = _make(CandleScene)

	candle._process(100.0)

	assert_almost_eq(candle.fuel.fill, 1.0, 0.0001,
		"an unlit light never consumes fuel while not burning")
