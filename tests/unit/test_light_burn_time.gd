# Pins the FUEL-MODEL burn values on the light family, replacing the pre-fuel
# burn_time pins (CONTRACT CHANGE, expected per the fuel design:
# docs/plans/light-source-fuel-design.md section 9 step 4 says "old burn_time
# defaults become fill + burn_rate (same effective durations)"). The values are
# the 3.x ground truth (git show origin/main, identical in dev4):
#   candle 3600 s  -> WAX fill 1.0 at burn_rate 1/3600 (candle.gd _ready)
#   torch 600 s    -> WAX fill 1.0 at burn_rate 1/600 (torch.gd _ready)
#   lantern 1800 s when is_oil_based, else 3600 s -> OIL fill 1.0 at the
#       matching rate (lanterns.gd _ready)
#   candelabra 1000 s per candle -> per-candle WAX fill 1.0 at burn_rate
#       1/1000 (candelabra.gd BURN_SECONDS)
# A failure here is a real fuel-value regression, not an expected contract
# change anymore: this file is the post-refactor pin.
# Real lightweight scenes are used for candle/torch/lantern so the authored
# _ready code runs as authored. The candelabra scene embeds ~750 KB of mesh
# data, so the candelabra side runs the script bare in the tree; its _ready is
# node-guarded and builds the fuel states from number_of_candles alone.
extends GutTest

const CandleScene = preload("res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle.tscn")
const TorchScene = preload("res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/torch/torch.tscn")
const LanternScene = preload("res://scenes/objects/pickable_items/equipment/tool/light-sources/starstuff_lantern/starstuff_lantern.tscn")
const CandelabraScript = preload("res://scenes/objects/pickable_items/equipment/tool/light-sources/candelabra/candelabra.gd")


func _make_light_scene(scene : PackedScene):
	var light = scene.instantiate()
	return add_child_autofree(light)


func _assert_full_fuel(item, kind : FuelSource.FuelKind, burn_seconds : float, context : String) -> void:
	assert_almost_eq(item.fuel.fill, 1.0, 0.0001, context + ": a fresh light starts full")
	assert_eq(item.fuel.fuel_source.fuel_kind, kind, context + ": authored fuel kind")
	assert_almost_eq(item.fuel.fuel_source.burn_rate, 1.0 / burn_seconds, 0.000001,
		context + ": burn_rate matches the authored 3.x duration")
	assert_almost_eq(item.fuel.burn_seconds_remaining(), burn_seconds, 0.01,
		context + ": effective burn duration preserved")


func test_candle_fuel_burns_3600_seconds():
	var candle = _make_light_scene(CandleScene)

	_assert_full_fuel(candle, FuelSource.FuelKind.WAX, 3600.0, "candle")


func test_torch_fuel_burns_600_seconds():
	var torch = _make_light_scene(TorchScene)

	_assert_full_fuel(torch, FuelSource.FuelKind.WAX, 600.0, "torch")


func test_lantern_fuel_burns_3600_seconds_when_not_oil_based():
	var lantern = _make_light_scene(LanternScene)

	_assert_full_fuel(lantern, FuelSource.FuelKind.OIL, 3600.0, "non-oil lantern")


func test_lantern_fuel_burns_1800_seconds_when_oil_based():
	# The oil-based variants (omnidirectional, bullseye, dark lantern) are
	# authored exactly like this: the same lantern scene with
	# is_oil_based = true (see those .tscn files).
	var lantern = LanternScene.instantiate()
	lantern.is_oil_based = true
	add_child_autofree(lantern)

	_assert_full_fuel(lantern, FuelSource.FuelKind.OIL, 1800.0, "oil lantern")


func test_candelabra_candles_burn_1000_seconds_each():
	# The fuel states are built from number_of_candles alone, so they are
	# exercised without the tree (a bare EquipmentItem in the tree would trip
	# the HoldPosition marker resolution error).
	var candelabra = autofree(CandelabraScript.new())
	candelabra.number_of_candles = 3
	candelabra._setup_candle_fuel()

	assert_eq(candelabra.candle_fuel.size(), 3, "one fuel state per authored candle")
	for i in range(3):
		var fuel: FuelContainer = candelabra.candle_fuel[i]
		assert_almost_eq(fuel.fill, 1.0, 0.0001, "candle %d starts full" % (i + 1))
		assert_eq(fuel.fuel_source.fuel_kind, FuelSource.FuelKind.WAX,
			"candle %d is wax" % (i + 1))
		assert_almost_eq(fuel.fuel_source.burn_rate, 1.0 / 1000.0, 0.000001,
			"candle %d matches the authored 1000 s duration" % (i + 1))
