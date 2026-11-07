class_name TorchItem
extends DisposableLightItem
## Torch: a disposable wax-family light (pitch soaks the head; fuel design
## owner decision 5 maps it to the WAX carrier shape). Burn accounting is
## percentage fill in FuelContainer instead of a wall-clock timer; a torch
## burns down to empty and is done, and it is never refillable.


signal item_is_dropped

var is_lit : bool = false
var fuel : FuelContainer
var random_number : float
@export var life_percentage_lose : float = 0.0 # (float, 0.0, 1.0)
@export var prob_going_out : float = 0.0 # (float, 0.0, 1.0)

@onready var firelight = $FireOrigin/Fire/Light3D


func _ready():
	fuel = FuelContainer.new()
	# Authored 3.x burn duration: a full torch burns 600 s.
	fuel.set_fuel(FuelSource.FuelKind.WAX, 600.0)
	self.connect("item_is_dropped", Callable(self, "item_drop"))


func _process(delta: float) -> void:
	super._process(delta)
	if fuel != null and fuel.tick_burn(delta, is_lit):
		_on_light_depleted()


func light():
	if fuel == null or not fuel.can_burn():
		return
	$AnimationPlayer.play("flicker")
	$Sounds/LightSound.play()
	$Sounds/Burning.play()
	$FireOrigin/Fire.emitting = true
	$FireOrigin/EmberDrip.emitting = true
	$FireOrigin/Smoke.emitting = true
	firelight.visible = true
	$FireOrigin.visible = true # related to bugfix #604
	$MeshInstance3D.cast_shadow = false

	# Not audible yet: light noise lands with the hearing restore (ai-direction-design.md item 2).
	is_lit = true


func unlight():
	$AnimationPlayer.stop()
	$Sounds/Burning.stop()
	$FireOrigin/Fire.emitting = false
	$FireOrigin/EmberDrip.emitting = false
	$FireOrigin/Smoke.emitting = false
	firelight.visible = false
	$FireOrigin.visible = false # related to bugfix #604
	$MeshInstance3D.cast_shadow = true
	is_lit = false


func _item_state_changed(previous_state, current_state):
	if current_state == GlobalConsts.ItemState.INVENTORY:
		owner_character.inventory.switch_away_from_light(self)
	elif current_state == GlobalConsts.ItemState.DROPPED:
		# Emit only, like candle (Brooks audit 4.4): the drop penalty applies
		# exactly once through the declared item_is_dropped signal, which is
		# connected in _ready (the old emit here had no listeners, so the
		# penalty only ran through the deleted direct item_drop() call).
		self.emit_signal("item_is_dropped")


func _use_primary():
	if is_lit == false:
		light()
	else:
		unlight()
		$Sounds/BlowOutSound.play()


func _on_light_depleted():
	unlight()


func item_drop():
	# Drop penalty (3.x life_percentage_lose semantics) applied to the fuel
	# fill, exactly once per drop.
	if fuel != null and fuel.fuel_source != null:
		fuel.fill -= fuel.fill * life_percentage_lose
	random_number = randf_range(0.0, 1.0)

	if angular_velocity.length() > 5:
		if random_number < prob_going_out:
			unlight()
