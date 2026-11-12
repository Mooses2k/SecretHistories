class_name TorchItem
extends DisposableLightItem
## Torch: a disposable wax-family light (pitch soaks the head; fuel design
## owner decision 5 maps it to the WAX carrier shape). Burn accounting is
## percentage fill in FuelContainer instead of a wall-clock timer; a torch
## burns down to empty and is done, and it is never refillable.
## Owner ruling (melee parity lane): a lit torch swings as an improvised cut
## weapon; an unlit torch lights on use; holding the use key never swings
## (the held-use gate raises the light instead). 3.x had no torch melee; this
## is owner-ruled beyond parity. Torch-local cut machinery: second user of
## the melee cut pattern, a shared strike component is deferred until a third
## appears (Rule of Three valve).


signal item_is_dropped

var is_lit : bool = false
var fuel : FuelContainer
var random_number : float
@export var life_percentage_lose : float = 0.0 # (float, 0.0, 1.0)
@export var prob_going_out : float = 0.0 # (float, 0.0, 1.0)

# Cut stats, owner-tunable exports (no 3.x reference values exist). A burning
# stick slashes plus burns; the pair mirrors the melee cut component shape.
@export var cut_damage_type1 : int = 1 # (GlobalConsts.AttackTypes) SLASHING
@export var cut_damage1 : int = 12
@export var cut_damage_type2 : int = 4 # (GlobalConsts.AttackTypes) FIRE
@export var cut_damage2 : int = 8
@export var cut_cooldown : float = 1.0

var can_hit := false
var on_cooldown := false

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
	elif not on_cooldown:
		attack_cut()


## Held use is declared so a hold never swings: item_controller routes holds
## into set_held_use, which raises the light (the owner-ruled light hold-up)
## and taps fire use_primary on release, exactly like melee items. The raise
## only fits the main hand: the tree's raised ready pose lives on the right
## arm chain, and an offhand torch has no left-side raise param.
func _has_held_use() -> bool:
	return true


func _set_held_use(enabled : bool) -> void:
	if owner_character == null:
		return
	if owner_character.has_method("set_light_hold_up"):
		owner_character.set_light_hold_up(enabled and _held_in_main_hand())


## The torch cut: same cooldown, sound, damage and animation-request shape as
## MeleeItem.attack_cut. The tap-to-blow-out slot is taken by the swing; a lit
## torch goes out by depletion and the drop rule only.
func attack_cut() -> void:
	can_hit = true
	$Sounds/Cut.play()
	$CooldownTimer.start(cut_cooldown)
	on_cooldown = true
	_play_cut_effects()


func _play_cut_effects() -> void:
	if owner_character == null:
		return
	if owner_character.has_method("play_melee_attack"):
		owner_character.play_melee_attack(&"attack_cut", not _held_in_main_hand(), 1.0)
	if owner_character.has_method("apply_attack_noise"):
		owner_character.apply_attack_noise(10.0)


## Right hand unless the owning inventory holds this torch in the offhand slot.
func _held_in_main_hand() -> bool:
	if owner_character == null:
		return true
	var inventory_value: Variant = owner_character.get("inventory")
	var inventory: Inventory = inventory_value as Inventory
	if inventory == null:
		return true
	if inventory.get_offhand_item() == self:
		return false
	return true


func _on_CooldownTimer_timeout() -> void:
	on_cooldown = false
	can_hit = false


func _on_Hitbox_hit(other):
	if not can_hit:
		return
	var hurtbox := other as Hurtbox
	if hurtbox == null:
		return
	var hit_owner: Node = hurtbox.owner_node
	if hit_owner == null or hit_owner == owner_character:
		return
	hurtbox.damage(cut_damage1, cut_damage_type1)
	hurtbox.damage(cut_damage2, cut_damage_type2)
	can_hit = false


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
