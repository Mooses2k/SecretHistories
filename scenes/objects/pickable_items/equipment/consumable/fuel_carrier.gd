class_name FuelCarrierItem
extends ConsumableItem
## Fuel carrier item (fuel design doc section 6, owner decision 5): the
## single-use carrier shape that holds a percentage fill of one fuel kind and
## refills same-kind light containers through their _use_reload() medical
## seam. The carrier itself never burns; a drained carrier stays in the world
## at fill 0.0 instead of being consumed (Noita rule). Fuel containers read
## exactly these two properties through FuelContainer.refill_from.

@export var fuel_source: FuelSource
@export var fill: float = 1.0
