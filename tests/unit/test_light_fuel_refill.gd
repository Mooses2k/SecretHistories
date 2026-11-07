# Pins the light-fuel refill seam (fuel design doc section 6, owner decisions
# 1 and 5, medical-reload baseline):
#   - Noita percentage exchange: needed = 1 - fill, given = min(needed, carrier
#     fill); the drained carrier STAYS in the world (and in its hotbar slot)
#     at fill 0.0 instead of being consumed.
#   - Same kind only: wax into wax, oil into oil; a mismatched kind is
#     rejected with a diegetic cue and no transfer.
#   - Refill NEVER changes lighting state: it does not light, does not
#     extinguish.
#   - Candles are the carrier itself and are NOT refillable.
# The lantern scene is lightweight and real; carriers are FuelCarrierItem
# instances (the production carrier shape; no fuel-carrier scene ships yet).
extends GutTest

const LanternScene = preload("res://scenes/objects/pickable_items/equipment/tool/light-sources/starstuff_lantern/starstuff_lantern.tscn")
const CandleScene = preload("res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/candle.tscn")
const InventoryScript = preload("res://scenes/characters/inventory.gd")
const EquipmentScript = preload("res://scenes/objects/pickable_items/equipment/equipment_item.gd")


class StubCharacter extends Node:
	var inventory : Inventory


func _make_oil_carrier(fill : float) -> FuelCarrierItem:
	var carrier: FuelCarrierItem = autofree(FuelCarrierItem.new())
	carrier.fuel_source = FuelSource.new()
	carrier.fuel_source.fuel_kind = FuelSource.FuelKind.OIL
	carrier.fill = fill
	return carrier


func _make_wax_carrier(fill : float) -> FuelCarrierItem:
	var carrier: FuelCarrierItem = autofree(FuelCarrierItem.new())
	carrier.fuel_source = FuelSource.new()
	carrier.fuel_source.fuel_kind = FuelSource.FuelKind.WAX
	carrier.fill = fill
	return carrier


func _make_lantern(fill : float) -> LanternItem:
	var lantern: LanternItem = add_child_autofree(LanternScene.instantiate())
	lantern.fuel.fill = fill
	return lantern


func test_same_kind_refill_transfers_min_space_carrier_fill():
	var tank := FuelContainer.new()
	tank.set_fuel(FuelSource.FuelKind.OIL, 3600.0)
	tank.fill = 0.5
	var carrier := _make_oil_carrier(1.0)

	var outcome := tank.refill_from(carrier)

	assert_eq(outcome, FuelContainer.RefillOutcome.TRANSFERRED, "same-kind refill transfers")
	assert_almost_eq(tank.fill, 1.0, 0.0001, "the container takes min(space, carrier fill)")
	assert_almost_eq(carrier.fill, 0.5, 0.0001, "the carrier keeps its remainder")


func test_partial_carrier_leaves_drained_carrier_in_the_world():
	var tank := FuelContainer.new()
	tank.set_fuel(FuelSource.FuelKind.OIL, 3600.0)
	tank.fill = 0.5
	var carrier := _make_oil_carrier(0.2)

	var outcome := tank.refill_from(carrier)

	assert_eq(outcome, FuelContainer.RefillOutcome.TRANSFERRED, "a partial carrier still transfers")
	assert_almost_eq(tank.fill, 0.7, 0.0001, "the container gains exactly the carrier fill")
	assert_almost_eq(carrier.fill, 0.0, 0.0001, "the drained carrier rests at fill 0.0")


func test_mismatched_kind_is_rejected():
	var tank := FuelContainer.new()
	tank.set_fuel(FuelSource.FuelKind.OIL, 3600.0)
	tank.fill = 0.5
	var wax := _make_wax_carrier(1.0)

	var outcome := tank.refill_from(wax)

	assert_eq(outcome, FuelContainer.RefillOutcome.KIND_MISMATCH,
		"wax cannot go into an oil container (owner decision 1)")
	assert_almost_eq(tank.fill, 0.5, 0.0001, "a rejected exchange transfers nothing")
	assert_almost_eq(wax.fill, 1.0, 0.0001, "a rejected exchange leaves the carrier untouched")


func test_full_container_reports_full():
	var tank := FuelContainer.new()
	tank.set_fuel(FuelSource.FuelKind.OIL, 3600.0)
	tank.fill = 1.0
	var carrier := _make_oil_carrier(1.0)

	assert_eq(tank.refill_from(carrier), FuelContainer.RefillOutcome.FULL,
		"refilling a full container is a no-op")


func test_empty_carrier_reports_empty():
	var tank := FuelContainer.new()
	tank.set_fuel(FuelSource.FuelKind.OIL, 3600.0)
	tank.fill = 0.5

	assert_eq(tank.refill_from(_make_oil_carrier(0.0)), FuelContainer.RefillOutcome.EMPTY_CARRIER,
		"an empty carrier gives nothing")


func test_non_carrier_object_is_rejected():
	var tank := FuelContainer.new()
	tank.set_fuel(FuelSource.FuelKind.OIL, 3600.0)

	assert_eq(tank.refill_from(autofree(EquipmentScript.new())),
		FuelContainer.RefillOutcome.NOT_CARRIER,
		"only fuel carriers can refill a container")


func test_refill_does_not_auto_light_or_extinguish():
	var lantern := _make_lantern(0.5)
	var inv: Inventory = add_child_autofree(InventoryScript.new())
	var character: StubCharacter = autofree(StubCharacter.new())
	character.inventory = inv
	lantern.owner_character = character
	inv.hotbar[2] = _make_oil_carrier(1.0)

	lantern.use_reload()

	assert_false(lantern.is_lit, "refilling an unlit lantern must not light it")

	lantern.light()
	inv.hotbar[2].fill = 1.0  # restore the carrier for the second pass

	lantern.use_reload()

	assert_true(lantern.is_lit, "refilling a lit lantern must not extinguish it")


func test_lantern_reload_scans_the_hotbar_and_keeps_the_drained_carrier():
	var lantern := _make_lantern(0.25)
	var inv: Inventory = add_child_autofree(InventoryScript.new())
	var character: StubCharacter = autofree(StubCharacter.new())
	character.inventory = inv
	lantern.owner_character = character
	var carrier := _make_oil_carrier(0.5)
	inv.hotbar[2] = carrier

	lantern.use_reload()

	assert_almost_eq(lantern.fuel.fill, 0.75, 0.0001, "the lantern gains the carrier fill")
	assert_almost_eq(carrier.fill, 0.0, 0.0001, "the drained carrier rests at fill 0.0")
	assert_eq(inv.hotbar[2], carrier,
		"the drained carrier stays in its hotbar slot instead of being consumed")


func test_kind_mismatch_refill_cue_plays_without_transfer():
	var lantern := _make_lantern(0.5)
	var inv: Inventory = add_child_autofree(InventoryScript.new())
	var character: StubCharacter = autofree(StubCharacter.new())
	character.inventory = inv
	lantern.owner_character = character
	var wax := _make_wax_carrier(1.0)
	inv.hotbar[1] = wax

	lantern.use_reload()

	assert_almost_eq(lantern.fuel.fill, 0.5, 0.0001, "the mismatched exchange transfers nothing")
	assert_true(lantern.get_node("BlowOutSound").playing,
		"a rejected mismatched-kind exchange plays the diegetic cue")


func test_candles_are_not_refillable():
	var candle: CandleItem = add_child_autofree(CandleScene.instantiate())
	candle.fuel.fill = 0.25

	candle.use_reload()

	assert_almost_eq(candle.fuel.fill, 0.25, 0.0001,
		"a candle is the carrier itself: use_reload must not change its fuel")


func test_candles_are_not_hotbar_refill_sources():
	# Owner decision 5: the candle is a carrier shaped item, but its exchange
	# into a container goes through the candelabra socket work, not the
	# percentage pour. FuelContainer only recognizes the FuelCarrierItem shape.
	var candle: CandleItem = add_child_autofree(CandleScene.instantiate())

	assert_false(FuelContainer.is_fuel_carrier(candle),
		"a candle must not act as a percentage refill source in v1")
