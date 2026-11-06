# Pins the CURRENT burn-time values AS AUTHORED on the candle family
# (Brooks Wave 1 row 7 companion; values per the landscape audit in
# docs/plans/light-source-fuel-design.md section 1):
#   candle 3600 s (candle.gd _ready)
#   torch 600 s (torch.gd _ready)
#   lantern 1800 s when is_oil_based, else 3600 s (lanterns.gd _ready)
#   candelabra 1000 s (candelabra.gd class default)
# NOTE FOR THE FuelContainer REFACTOR: this test documents TODAY'S contract
# as the pre-refactor baseline. The FuelContainer refactor (same design doc,
# section 3) replaces burn_time defaults with fill + burn_rate at the same
# effective durations and MUST CONSCIOUSLY UPDATE this test when it lands;
# a failure here after that refactor is an expected contract change, not a
# regression.
# Real scenes and scripts are used: candle/torch/lantern load their real
# lightweight scenes in-tree so the authored _ready code runs as authored.
# Candelabra is pinned at its authored class
# default, which its _ready leaves untouched; its scene embeds ~750 KB of
# mesh data and is not needed for that value.
extends GutTest

const CandleScene = preload("res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle.tscn")
const TorchScene = preload("res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/torch/torch.tscn")
const LanternScene = preload("res://scenes/objects/pickable_items/equipment/tool/light-sources/starstuff_lantern/starstuff_lantern.tscn")
const CandelabraScript = preload("res://scenes/objects/pickable_items/equipment/tool/light-sources/candelabra/candelabra.gd")


func _make_light_scene(scene : PackedScene):
	var light = scene.instantiate()
	return add_child_autofree(light)


func test_candle_burn_time_is_3600_seconds():
	var candle = _make_light_scene(CandleScene)

	assert_eq(candle.burn_time, 3600.0, "authored candle burn duration")


func test_torch_burn_time_is_600_seconds():
	var torch = _make_light_scene(TorchScene)

	assert_eq(torch.burn_time, 600.0, "authored torch burn duration")


func test_lantern_burn_time_is_3600_seconds_when_not_oil_based():
	var lantern = _make_light_scene(LanternScene)

	assert_eq(lantern.burn_time, 3600.0, "authored non-oil lantern burn duration")


func test_lantern_burn_time_is_1800_seconds_when_oil_based():
	# The oil-based variants (omnidirectional, bullseye, dark lantern) are
	# authored exactly like this: the same lantern scene with
	# is_oil_based = true (see those .tscn files).
	var lantern = LanternScene.instantiate()
	lantern.is_oil_based = true
	add_child_autofree(lantern)

	assert_eq(lantern.burn_time, 1800.0, "authored oil lantern burn duration")


func test_candelabra_burn_time_default_is_1000_seconds():
	var candelabra = autofree(CandelabraScript.new())

	assert_eq(candelabra.burn_time, 1000.0, "authored candelabra burn duration")
