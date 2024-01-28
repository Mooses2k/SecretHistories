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
@export var primary_damage_type1 : int = 0 # (AttackTypes.Types)
@export var primary_damage1 = 0
@export var primary_damage_type2 : int = 0 # (AttackTypes.Types)
@export var primary_damage2 = 0
@export var secondary_damage_type1 : int = 0 # (AttackTypes.Types)
@export var secondary_damage1 = 0
@export var secondary_damage_type2 : int = 0 # (AttackTypes.Types)
@export var secondary_damage2 = 0
@export var melee_attack_speed : float = 1.0
@export var cooldown = 0.01

#export var element_path : NodePath
#onready var collision_and_mesh = get_node(element_path)

var can_hit = false
var did_a_thrust = false
var did_a_cut = false
var on_cooldown = false

@onready var melee_hitbox = $Hitbox as Area3D


func attack_thrust():
	can_hit = true
	did_a_thrust = true
	$Sounds/Thrust.play()
	$CooldownTimer.start(cooldown)
	on_cooldown = true
#	emit_signal("on_attack")  #not used at the moment; should be used to signal up to Animation Player and Hitbox?
	
#	var melee_anim
#	if weapon_type == WeaponType.COMPLEX_HILT_ONE_HAND:
#		melee_anim = owner_character.find_node("SabreTechniques")
#		if not melee_anim.is_playing():
#			can_hit = true
#			melee_anim.play("ThrustFromTierce")
#			$Sounds/Thrust.play()
#			yield(melee_anim, "animation_finished")
#			owner_character.stamina -= 30
#			can_hit = false
#			melee_anim.queue("RecoveryThrustToTierce")
#	if weapon_type == WeaponType.POLEARM:
#		melee_anim = owner_character.find_node("PolearmTechniques")
#		if not melee_anim.is_playing():
#			can_hit = true
#			melee_anim.play("polearm_thrust_from_right")
#			$Sounds/Thrust.play()
#			yield(melee_anim, "animation_finished")
#			character.stamina -= 30 # this is bugged with halberd
#			can_hit = false
#			melee_anim.queue("polearm_recovery_from_right")


func attack_cut():
	can_hit = true
	did_a_cut = true
	$Sounds/Cut.play()
	$CooldownTimer.start(cooldown)
	on_cooldown = true
#	emit_signal("on_attack")  #not used at the moment; should be used to signal up to Animation Player and Hitbox?
	
#	var melee_anim
#	if weapon_type == 3:
#		melee_anim = owner_character.find_node("SabreTechniques")
#		if not melee_anim.is_playing():
#			can_hit = true
#			melee_anim.play("Swing1FromTierce")
#			$Sounds/Cut.play()
#			yield(melee_anim, "animation_finished")
#			owner_character.stamina -= 50
#			can_hit = false
#			melee_anim.queue("Recovery1ToTierce")
#	if weapon_type == 6:
#		melee_anim = owner_character.find_node("PolearmTechniques")
#		if not melee_anim.is_playing():
#			can_hit = true
#			melee_anim.play("polearm_cut_2") # WIP, AnimationPlayer got wiped during import_items merge
#			$Sounds/Cut.play()
#			yield(melee_anim, "animation_finished")
#			character.stamina -= 50
#			can_hit = false
#			melee_anim.queue("polearm_cut_2_recovery") # WIP, AnimationPlayer got wiped during import_items merge


func _use_primary():
	if not on_cooldown:
		attack_thrust()


func _use_secondary():
	if not on_cooldown:
		attack_cut()


#	TODO: Changing the status of the weapon (dropping the weapon or unequiping it)
# while one of these timers is active should appropriately reset the timer and deal any of it's side effects
#
# currently if changed away from and changed back to melee weapon, first swing does nothing


func melee_throw_damage():
	var item_damage
	
	if can_spin:
		print("Item thrown can spin")
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
	if can_hit and other.owner != owner_character and other.owner.has_method("damage"):
		if did_a_thrust:
			other.owner.damage(primary_damage1, primary_damage_type1, other)
			other.owner.damage(primary_damage2, primary_damage_type2, other)
		if did_a_cut:
			other.owner.damage(secondary_damage1, secondary_damage_type1, other)
			other.owner.damage(secondary_damage1, secondary_damage_type2, other)
		can_hit = false


func _on_Hitbox_body_entered(body):
	print(body, " hit by", self)
	# This is so slashing damage doesn't impulse objects as much
	if primary_damage_type1 == 0:
		primary_damage1 / 2
	elif primary_damage_type2 == 0:
		primary_damage2 / 2
	elif secondary_damage_type1 == 0:
		secondary_damage1 / 2
	elif secondary_damage_type2 == 0:
		secondary_damage2 / 2
	
	# This pushes the hit object if it's a RigidBody
	if body is RigidBody3D and can_hit == true:
		# TODO: fix this, it's always pointing one direction possible because base character scene doesn't rotate?
		body.apply_central_impulse(-owner_character.global_transform.basis.z * primary_damage1)
		body.apply_central_impulse(-owner_character.global_transform.basis.z * primary_damage2)
		body.apply_central_impulse(-owner_character.global_transform.basis.z * secondary_damage1)
		body.apply_central_impulse(-owner_character.global_transform.basis.z * secondary_damage2)
