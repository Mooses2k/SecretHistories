class_name MeleeItem
extends EquipmentItem


enum WeaponType {
	ROCK,
	KNIFE,
	SIMPLE_HILT_ONE_HAND,
	COMPLEX_HILT_ONE_HAND,
	TWO_HANDED_SWORD,
	WOODAXE_AND_SLEDGE,
	POLEARM,
	COUNT
}

@export var weapon_type: WeaponType = 0

# primary and secondary here refer to primary use (L-Click) and secondary use (R-Click)
@export var primary_damage_type1 : int = 0 # (GlobalConsts.AttackTypes)
@export var primary_damage1 : int = 0
@export var primary_damage_type2 : int = 0 # (GlobalConsts.AttackTypes)
@export var primary_damage2 : int = 0
@export var secondary_damage_type1 : int = 0 # (GlobalConsts.AttackTypes)
@export var secondary_damage1 : int = 0
@export var secondary_damage_type2 : int = 0 # (GlobalConsts.AttackTypes)
@export var secondary_damage2 : int = 0
@export var melee_attack_speed : float = 1.0
@export var cooldown : float = 0.01

#export var element_path : NodePath
#onready var collision_and_mesh = get_node(element_path)

var can_hit = false
var did_a_thrust = false
var did_a_cut = false
var on_cooldown = false

@onready var melee_hitbox = $Hitbox as Area3D


func attack_cut():
	can_hit = true
	did_a_cut = true
	$Sounds/Cut.play()
	$CooldownTimer.start(cooldown)
	on_cooldown = true
	_play_attack_effects(&"attack_cut", 10.0)


func attack_thrust():
	can_hit = true
	did_a_thrust = true
	$Sounds/Thrust.play()
	$CooldownTimer.start(cooldown)
	on_cooldown = true
	_play_attack_effects(&"attack_thrust", 8.0)


func _has_held_use() -> bool:
	return true


## 3.x input parity: Left-Click thrust, Right-Click cut. The item owns the
## attack fact, so the animation request and the attack noise fire from the
## attack entry points for both the player path and the AI path.
func _use_primary():
	if not on_cooldown:
		attack_thrust()


func _use_secondary():
	if not on_cooldown:
		attack_cut()


func _play_attack_effects(attack : StringName, noise : float) -> void:
	if owner_character == null:
		return
	if owner_character.has_method("play_melee_attack"):
		owner_character.play_melee_attack(attack, not _held_in_main_hand(), melee_attack_speed)
	if owner_character.has_method("apply_attack_noise"):
		owner_character.apply_attack_noise(noise)


## Right hand unless the owning inventory holds this item in the offhand slot.
## Items outside a normal equip slot (mid-equip, AI-injected) use the main hand.
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


#	TODO: Changing the status of the weapon (dropping the weapon or unequiping it)
# while one of these timers is active should appropriately reset the timer and deal any of it's side effects
#
# currently if changed away from and changed back to melee weapon, first swing does nothing


func melee_throw_damage() -> int:
	var item_damage = -1

	if can_spin:
		item_damage = secondary_damage1 + secondary_damage2
		print(item_damage, " damage calculated")
	elif thrown_point_first:
		item_damage = primary_damage1 + primary_damage2
		print(item_damage, " damage calculated")

	return item_damage


# Make sure that this is always connected from each individual weapon's scene
func _on_CooldownTimer_timeout() -> void:
	on_cooldown = false
	did_a_cut = false
	did_a_thrust = false


func _on_Hitbox_hit(other):
	if not can_hit:
		return
	var hurtbox := other as Hurtbox
	if hurtbox == null:
		return
	var hit_owner: Node = hurtbox.owner_node
	if hit_owner == null or hit_owner == owner_character:
		return
	# dev4 damage path: the hurtbox emits damaged into its owner's state
	# (humanoid_character_state._on_damaged), mirroring the kick. Direction
	# and origin stay at their defaults: 3.x melee applied no swing impulse.
	if did_a_thrust:
		hurtbox.damage(primary_damage1, primary_damage_type1)
		hurtbox.damage(primary_damage2, primary_damage_type2)
	if did_a_cut:
		hurtbox.damage(secondary_damage1, secondary_damage_type1)
		hurtbox.damage(secondary_damage2, secondary_damage_type2)
	can_hit = false


# Swing damage total for the current attack mode, mirroring the Hurtbox
# resolution in _on_Hitbox_hit: a thrust sums the primary components, a cut
# sums the secondary components.
func _swing_damage() -> int:
	if did_a_thrust:
		return primary_damage1 + primary_damage2
	if did_a_cut:
		return secondary_damage1 + secondary_damage2
	return 0


func _on_Hitbox_body_entered(body):
	prints(body, "hit by", self)
	# Bludgeoning melee hits (damage 15 or over, the kick bar) accumulate on
	# rigid large objects such as breakable statues. The rigid-body guard,
	# the bar and the has_method guard all live in LargeObjectShared so this
	# stays a one-line call (DRY); idle touches (can_hit false) never count.
	if can_hit:
		LargeObjectShared.accumulate_bludgeoning_damage(body, _swing_damage())
	# Slashing damage halves its impulse factor as a LOCAL value at the damage
	# call, never by mutating the exported stats here (Brooks audit 4.1): the
	# old primary_damage1 /= 2 pattern permanently corrupted the weapon's
	# damage for every later hit once any body touched the hitbox. The only
	# consumer of halved values (the impulse block below) is currently
	# commented out, so there is no live local factor to compute today.

	# This pushes the hit object if it's a RigidBody
	#if body is RigidBody3D and can_hit == true:
		## TODO: fix this, it's always pointing one direction possible because base character scene doesn't rotate?
		#body.apply_central_impulse(-owner_character.global_transform.basis.z * primary_damage1)
		#body.apply_central_impulse(-owner_character.global_transform.basis.z * primary_damage2)
		#body.apply_central_impulse(-owner_character.global_transform.basis.z * secondary_damage1)
		#body.apply_central_impulse(-owner_character.global_transform.basis.z * secondary_damage2)
