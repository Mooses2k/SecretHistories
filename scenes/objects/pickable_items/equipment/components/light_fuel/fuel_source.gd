class_name FuelSource
extends Resource
## Fuel kind data for light-source fuel (docs/plans/light-source-fuel-design.md
## section 6). One instance per burning object: the burn rate is authored from
## that object's effective 3.x burn duration, so the same WAX kind burns at
## different rates in a 3600 s candle and a 1000 s candelabra candle.

enum FuelKind { WAX, OIL }


@export var fuel_kind: FuelKind = FuelKind.WAX
## Fraction of the holding container consumed per second while lit. Authored
## per burning object: 1.0 / 3600.0 means a full container lasts one hour.
@export var burn_rate: float = 1.0 / 3600.0
