class_name LanternItem
extends ToolItem
## Lantern: an OIL fuel container (fuel design owner decision 5). Burn
## accounting is percentage fill in FuelContainer instead of a wall-clock
## timer; refills come from same-kind oil carriers through the _use_reload()
## medical-reload seam and never change the lighting state. The belt-attach
## path is unchanged.


signal item_is_dropped

var is_lit : bool = false
var fuel : FuelContainer
var random_number : float
@export var is_oil_based : bool = false
@export var life_percentage_lose : float = 0.0 # (float, 0.0, 1.0)
@export var prob_going_out : float = 0.0 # (float, 0.0, 1.0)

var mesh_instance : Node
@onready var firelight = $Light3D


func _ready():
	fuel = FuelContainer.new()
	fuel.fuel_source = FuelSource.new()
	fuel.fuel_source.fuel_kind = FuelSource.FuelKind.OIL
	# Authored 3.x burn durations: oil lanterns 1800 s, non-oil 3600 s.
	if is_oil_based:
		fuel.fuel_source.burn_rate = 1.0 / 1800.0
	else:
		fuel.fuel_source.burn_rate = 1.0 / 3600.0

	if is_instance_valid($MeshInstance3D):
		mesh_instance = $MeshInstance3D
	self.connect("item_is_dropped", Callable(self, "item_drop"))


func _process(delta):
	super._process(delta)
	if fuel != null and fuel.tick_burn(delta, is_lit):
		_on_light_depleted()
	# With Spotlight3D, the light doesn't fall on the holder, but they should still be visible
	if is_instance_valid(owner_character):
		if is_lit and owner_character.light_level < 0.01:
			owner_character.light_level = 0.01


func _use_primary():
	if is_lit == false:
		light()
	else:
		unlight()
		if !is_in_belt:
			$BlowOutSound.play()


func light():
	if fuel == null or not fuel.can_burn():
		return
	if !is_in_belt:
		$LightSound.play()
	else:
		$SlideOpen.play()

	# Not audible yet: light noise lands with the hearing restore (ai-direction-design.md item 2).

	$AnimationPlayer.play("flicker")
	firelight.visible = true
	var fire_origin: Node3D = get_node_or_null("FireOrigin")
	if fire_origin != null:
		fire_origin.visible = true # related to bugfix #604
	$MeshInstance3D.cast_shadow = false

	is_lit = true


func unlight():
	if is_in_belt:
		$SlideClosed.play()

	$AnimationPlayer.stop()
	firelight.visible = false
	var fire_origin: Node3D = get_node_or_null("FireOrigin")
	if fire_origin != null:
		fire_origin.visible = false # related to bugfix #604
	$MeshInstance3D.cast_shadow = true

	is_lit = false


func _item_state_changed(previous_state, current_state):
	if current_state == GlobalConsts.ItemState.INVENTORY:
		owner_character.inventory.switch_away_from_light(self)
	elif current_state == GlobalConsts.ItemState.DROPPED:
		# Emit only, like candle (Brooks audit 4.4): the drop penalty applies
		# exactly once through the declared item_is_dropped signal, connected
		# in _ready (the old emit had no listeners next to a direct call).
		self.emit_signal("item_is_dropped")


func _on_light_depleted():
	unlight()


## Medical-reload interaction baseline (fuel design section 6, owner decision
## 1): tap reload scans the hotbar through the data-returning
## search_hotbar_matched seam (no assignment inside lambdas, Brooks audit 1.1),
## transfers percentage fill from same-kind fuel carriers, keeps drained
## carriers at fill 0.0, and NEVER lights or extinguishes the lantern. A
## mismatched-kind carrier produces a diegetic rejection cue and no transfer.
func _use_reload() -> void:
	if fuel == null or fuel.fuel_source == null:
		return
	if owner_character == null:
		return
	var inv: Inventory = owner_character.inventory
	if inv == null:
		return

	var carriers: Array = inv.search_hotbar_matched(Callable(self, "_is_scannable_fuel_carrier"))
	var transferred := false
	var kind_mismatch_seen := false
	for pair in carriers:
		if fuel.fill >= 1.0:
			break
		var carrier: Object = pair[0]
		var carrier_source: FuelSource = carrier.get("fuel_source")
		if carrier_source.fuel_kind != fuel.fuel_source.fuel_kind:
			kind_mismatch_seen = true
			continue
		if fuel.refill_from(carrier) == FuelContainer.RefillOutcome.TRANSFERRED:
			transferred = true

	if kind_mismatch_seen and not transferred:
		_play_refill_rejected_cue()
	emit_signal("item_data_changed")


func _is_scannable_fuel_carrier(item: Object) -> bool:
	if not FuelContainer.is_fuel_carrier(item):
		return false
	var carrier_fill: float = item.get("fill")
	return carrier_fill > 0.0


## v1 diegetic cue for a rejected same-kind exchange: the existing blow-out
## puff. The owner can swap in a dedicated slosh/sputter asset later. Some
## lantern variants author this node as a 3D player, so the type stays loose.
func _play_refill_rejected_cue() -> void:
	var cue: Node = get_node_or_null("BlowOutSound")
	if cue != null and cue.has_method("play"):
		cue.play()


func item_drop():
	# Drop penalty (3.x life_percentage_lose semantics) applied to the fuel
	# fill, exactly once per drop.
	if fuel != null and fuel.fuel_source != null:
		fuel.fill -= fuel.fill * life_percentage_lose
	random_number = randf_range(0.0, 1.0)

	if linear_velocity.length() > 0.01:
		if random_number < prob_going_out:
			unlight()
