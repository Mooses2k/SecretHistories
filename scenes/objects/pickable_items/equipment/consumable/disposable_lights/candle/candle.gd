class_name CandleItem
extends DisposableLightItem
## Candle: a disposable light that is the wax carrier itself (fuel design owner
## decision 5). Burn accounting is percentage fill in FuelContainer instead of
## a wall-clock timer; the candle burns down to empty and is done, and it is
## never refillable.


signal item_is_dropped

var is_lit : bool = false
var fuel : FuelContainer
var random_number : float
@export var life_percentage_lose : float = 0.0 # (float, 0.0, 1.0)
@export var prob_going_out : float = 0.0 # (float, 0.0, 1.0)

@onready var firelight = $FireOrigin/Fire/Light3D


func _ready() -> void:
	fuel = FuelContainer.new()
	# Authored 3.x burn duration: a full candle burns 3600 s.
	fuel.set_fuel(FuelSource.FuelKind.WAX, 3600.0)
	self.connect("item_is_dropped", Callable(self, "item_drop"))


func _process(delta: float) -> void:
	super._process(delta)
	if fuel != null and fuel.tick_burn(delta, is_lit):
		_on_light_depleted()


func light() -> void:
	if fuel == null or not fuel.can_burn():
		return
	$AnimationPlayer.play("flicker")
	$Sounds/LightSound.play()
	$MeshInstance3D.get_surface_override_material(0).emission_enabled = true
	$FireOrigin/Fire.visible = true
	firelight.visible = true
	$FireOrigin.visible = true # related to bugfix #604
	$MeshInstance3D.cast_shadow = false

	# Not audible yet: light noise lands with the hearing restore (ai-direction-design.md item 2).
	is_lit = true


func unlight() -> void:
	$AnimationPlayer.stop()
	$MeshInstance3D.get_surface_override_material(0).emission_enabled = false
	$FireOrigin/Fire.visible = false
	firelight.visible = false
	$FireOrigin.visible = false # related to bugfix #604
	$MeshInstance3D.cast_shadow = true
	is_lit = false


func _use_primary() -> void:
	if is_lit == false:
		light()
	else:
		unlight()
		$Sounds/BlowOutSound.play()


func _item_state_changed(previous_state, current_state):
	if current_state == GlobalConsts.ItemState.INVENTORY:
		owner_character.inventory.switch_away_from_light(self)
	elif current_state == GlobalConsts.ItemState.DROPPED:
		# Emit only (Brooks audit 4.4): the direct item_drop() call here used to
		# double-apply the burn penalty on top of the item_is_dropped signal.
		self.emit_signal("item_is_dropped")


func _on_light_depleted():
	unlight()


func item_drop():
	# Drop penalty (3.x life_percentage_lose semantics) applied to the fuel
	# fill, exactly once per drop through the emitted signal.
	if fuel != null and fuel.fuel_source != null:
		fuel.fill -= fuel.fill * life_percentage_lose
	random_number = randf_range(0.0, 1.0)

	if linear_velocity.length() > 0.001:
		if random_number < prob_going_out:
			unlight()
