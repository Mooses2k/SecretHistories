class_name FuelContainer
extends RefCounted
## Pure fuel accounting for light items (docs/plans/light-source-fuel-design.md
## section 6, owner decisions 1 and 5): percentage fill depletion while lit and
## same-kind percentage refill exchange. Lighting state (is_lit) stays on the
## owning item; this component never lights or extinguishes anything itself.

enum RefillOutcome { NOT_CARRIER, EMPTY_CARRIER, KIND_MISMATCH, FULL, TRANSFERRED }


var fuel_source: FuelSource
## Remaining fuel as a fraction of the container: 1.0 full, 0.0 burned out.
var fill: float = 1.0


## Authored fuel setup: one FuelSource carrying the item's effective 3.x burn
## duration, so old burn_time values carry over exactly as fill + burn_rate.
func set_fuel(kind: FuelSource.FuelKind, burn_seconds: float) -> void:
	fuel_source = FuelSource.new()
	fuel_source.fuel_kind = kind
	if burn_seconds <= 0.0:
		push_error("FuelContainer.set_fuel needs a positive burn duration")
		fuel_source.burn_rate = 1.0 / 3600.0
		return
	fuel_source.burn_rate = 1.0 / burn_seconds


func is_empty() -> bool:
	return fill <= 0.0


func can_burn() -> bool:
	return fuel_source != null and fill > 0.0


## Burns one frame while lit. Returns true when the fuel ran out during this
## tick, which is the owning item's cue to run its depletion chain. An unlit
## item never depletes.
func tick_burn(delta: float, lit: bool) -> bool:
	if not lit or not can_burn():
		return false
	fill = maxf(fill - fuel_source.burn_rate * delta, 0.0)
	return fill <= 0.0


## Remaining wall-clock burn seconds at the authored burn rate.
func burn_seconds_remaining() -> float:
	if fuel_source == null or fuel_source.burn_rate <= 0.0:
		return 0.0
	return fill / fuel_source.burn_rate


## Per-object light-output curve (owner decision 6): sublinear logarithmic
## growth with the per-object lit-candle count, normalized so ONE lit candle
## keeps its authored light energy and range:
## scale = (1 + gain * log2(1 + lit_count)) / (1 + gain).
## The consolidation proxy (design doc section 8) consumes the same helper.
static func light_scale_for(lit_count: int, gain: float) -> float:
	if lit_count <= 0:
		return 0.0
	var clamped_gain := maxf(gain, 0.0)
	var scaled := 1.0 + clamped_gain * log(1.0 + float(lit_count)) / log(2.0)
	return scaled / (1.0 + clamped_gain)


## A fuel carrier is any item exposing fuel_source (FuelSource) and fill
## (float) properties. FuelCarrierItem is the production shape; light carriers
## (candles) join the exchange through the candelabra socket work later.
static func is_fuel_carrier(item: Object) -> bool:
	if item == null or not is_instance_valid(item):
		return false
	return item.get("fuel_source") is FuelSource and item.get("fill") is float


## Noita-style percentage exchange on refill (owner decisions 1 and 5):
## needed = 1.0 - fill, given = min(needed, carrier fill), the container gains
## given and the carrier keeps its remainder at its reduced fill. Same kind
## only: mismatched kinds are rejected. A drained carrier stays in the world
## at fill 0.0 instead of being consumed. The refill NEVER changes lighting
## state: refilling does not light and does not extinguish.
func refill_from(carrier: Object) -> RefillOutcome:
	if carrier == null or not is_fuel_carrier(carrier):
		return RefillOutcome.NOT_CARRIER
	var source: FuelSource = carrier.get("fuel_source")
	if source == null:
		return RefillOutcome.NOT_CARRIER
	if fuel_source == null:
		push_error("FuelContainer.refill_from on a container without a fuel source")
		return RefillOutcome.NOT_CARRIER
	if source.fuel_kind != fuel_source.fuel_kind:
		return RefillOutcome.KIND_MISMATCH
	if fill >= 1.0:
		return RefillOutcome.FULL
	var carrier_fill: float = carrier.get("fill")
	if carrier_fill <= 0.0:
		return RefillOutcome.EMPTY_CARRIER
	var given := minf(1.0 - fill, carrier_fill)
	fill = minf(fill + given, 1.0)
	carrier.set("fill", carrier_fill - given)
	return RefillOutcome.TRANSFERRED
