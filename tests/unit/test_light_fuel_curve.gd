# Pins the per-object light-output log curve (fuel design owner decision 6:
# docs/plans/light-source-fuel-design.md sections 6 and 8). The curve is
# count-based by design: light output scales with the NUMBER of lit candles on
# the object, sublinear (logarithmic), normalized so one lit candle keeps its
# authored energy and range. It is applied per object: a candelabra with one
# candle left renders dimmer than a fully lit one. Single lights (candle,
# torch, lantern) have exactly one flame, so their output stays at the
# authored values; the LightCluster consolidation proxy (design doc section 8)
# consumes the same FuelContainer.light_scale_for helper.
# The candelabra stand is hand-built from lightweight nodes (the real scene
# embeds ~750 KB of mesh data) with the same node names the script resolves.
extends GutTest

const CandelabraScript = preload("res://scenes/objects/pickable_items/equipment/tool/light-sources/candelabra/candelabra.gd")


func _make_stand(count : int) -> CandelabraItem:
	# The stand runs OUT OF THE TREE on purpose: a bare EquipmentItem in the
	# tree trips the HoldPosition marker resolution error, and the fuel and
	# curve logic under test does not need a tree (per-candle fuel states and
	# light output are resolved from node paths that work detached).
	var candelabra: CandelabraItem = autofree(CandelabraScript.new())
	candelabra.number_of_candles = count

	var own_mesh := MeshInstance3D.new()
	own_mesh.name = "MeshInstance3D"
	own_mesh.mesh = BoxMesh.new()
	candelabra.add_child(own_mesh)

	for i in range(count):
		var candle := Node3D.new()
		candle.name = "Candle%d" % (i + 1)
		var fire_origin := Node3D.new()
		fire_origin.name = "FireOrigin"
		var fire := Node3D.new()
		fire.name = "Fire"
		var light := OmniLight3D.new()
		light.name = "Light3D"
		light.light_energy = 1.0
		light.omni_range = 9.0
		var mesh := MeshInstance3D.new()
		mesh.name = "MeshInstance3D"
		mesh.mesh = BoxMesh.new()
		mesh.set_surface_override_material(0, StandardMaterial3D.new())
		fire.add_child(light)
		fire_origin.add_child(fire)
		candle.add_child(fire_origin)
		candle.add_child(mesh)
		candelabra.add_child(candle)

	candelabra._setup_candle_fuel()
	candelabra._setup_base_light()
	return candelabra


func test_curve_sample_points():
	# scale = (1 + gain * log2(1 + n)) / (1 + gain), gain 0.5.
	assert_almost_eq(FuelContainer.light_scale_for(0, 0.5), 0.0, 0.0001,
		"no lit candles means no light output")
	assert_almost_eq(FuelContainer.light_scale_for(1, 0.5), 1.0, 0.0001,
		"one lit candle keeps its authored output")
	assert_almost_eq(FuelContainer.light_scale_for(2, 0.5), 1.195, 0.001,
		"two lit candles scale by the log curve")
	assert_almost_eq(FuelContainer.light_scale_for(3, 0.5), 1.3333, 0.001,
		"three lit candles scale by the log curve")
	assert_almost_eq(FuelContainer.light_scale_for(10, 0.5), 1.8198, 0.001,
		"ten lit candles stay well sublinear")


func test_curve_is_sublinear_and_monotonic():
	var two := FuelContainer.light_scale_for(2, 0.5)
	var three := FuelContainer.light_scale_for(3, 0.5)
	var ten := FuelContainer.light_scale_for(10, 0.5)

	assert_gt(three, two, "more lit candles are brighter")
	assert_gt(ten, three, "more lit candles are brighter")
	# Sublinear: each added candle contributes less than the one before.
	assert_lt(three - two, two - FuelContainer.light_scale_for(1, 0.5),
		"the curve must not grow linearly with the lit count")


func test_zero_gain_keeps_authored_output_at_any_count():
	assert_almost_eq(FuelContainer.light_scale_for(5, 0.0), 1.0, 0.0001,
		"gain 0 disables scaling")


func test_one_lit_candle_keeps_authored_light_values():
	var candelabra := _make_stand(1)

	candelabra.light()

	var firelight: OmniLight3D = candelabra.firelight
	assert_true(firelight.visible, "the flame light is on")
	assert_almost_eq(firelight.light_energy, 1.0, 0.0001,
		"one candle keeps the authored energy")
	assert_almost_eq(firelight.omni_range, 9.0, 0.0001,
		"one candle keeps the authored range")
	assert_eq(candelabra.count_lit_candles(), 1, "one lit candle")


func test_fully_lit_candelabra_is_brighter_than_authored_single():
	var candelabra := _make_stand(3)

	candelabra.light()

	var firelight: OmniLight3D = candelabra.firelight
	assert_eq(candelabra.count_lit_candles(), 3, "all three candles lit")
	assert_almost_eq(firelight.light_energy, FuelContainer.light_scale_for(3, 0.5), 0.001,
		"the flame light energy follows the curve over the lit count")
	assert_almost_eq(firelight.omni_range, 9.0 * FuelContainer.light_scale_for(3, 0.5), 0.001,
		"the flame light range grows to match")


func test_burn_down_rescales_the_output():
	var candelabra := _make_stand(3)
	candelabra.light()
	# Force candle 3 to burn out this tick: a 0.001 fill at rate 1.0/s.
	candelabra.candle_fuel[2].fuel_source.burn_rate = 1.0
	candelabra.candle_fuel[2].fill = 0.001

	candelabra._process(0.001)

	assert_eq(candelabra.count_lit_candles(), 2, "candle 3 burned out")
	var firelight: OmniLight3D = candelabra.firelight
	assert_almost_eq(firelight.light_energy, FuelContainer.light_scale_for(2, 0.5), 0.001,
		"the output rescales when a candle burns out")


func test_burn_down_of_all_candles_depletes_the_stand():
	var candelabra := _make_stand(3)
	candelabra.light()
	for i in range(3):
		candelabra.candle_fuel[i].fuel_source.burn_rate = 1.0
		candelabra.candle_fuel[i].fill = 0.001

	candelabra._process(0.001)

	assert_true(candelabra.is_depleted, "a stand with every candle burned out is depleted")
	assert_false(candelabra.is_lit, "a depleted stand is not lit")
	assert_false(candelabra.firelight.visible, "the flame light is off")
