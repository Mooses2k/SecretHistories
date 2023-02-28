extends EquipmentItem
class_name MeleeItem


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
export(WeaponType) var weapon_type : int = 0

# primary and secondary here refer to primary use (L-Click) and secondary use (R-Click)
export(AttackTypes.Types) var primary_damage_type1 : int = 0
export var primary_damage1 = 0
export(AttackTypes.Types) var primary_damage_type2 : int = 0
export var primary_damage2 = 0
export(AttackTypes.Types) var secondary_damage_type1 : int = 0
export var secondary_damage1 = 0
export(AttackTypes.Types) var secondary_damage_type2 : int = 0
export var secondary_damage2 = 0

onready var melee_hitbox = $Hitbox as Area
export var cooldown = 0.01

export var throw_logic : bool
export var can_spin : bool

#export var element_path : NodePath
#onready var collision_and_mesh = get_node(element_path)
export var normal_pos_path : NodePath
onready var normal_pos = get_node(normal_pos_path)
export var throw_pos_path : NodePath
onready var throw_pos = get_node(throw_pos_path)

var can_hit = false
var on_cooldown = false

onready var character = get_parent()


func _ready():
	pass


func _process(delta):
	if throw_logic == true :
		if item_state == GlobalConsts.ItemState.EQUIPPED:
			self.global_rotation = normal_pos.global_rotation


func apply_throw_logic(impulse):
	if throw_logic:
		self.global_rotation = throw_pos.global_rotation
	if can_spin:
		angular_velocity = Vector3(global_transform.basis.z * -15)
		apply_central_impulse(impulse)
	else:
		apply_central_impulse(impulse)


# Should be: Left-Click thrust, Right-Click cut, when nothing else, guard. Each attack has a recovery animation, but technically a thrust from one side should be able to recover to any of the guards
func attack_thrust():
	character = get_parent().get_parent()
	var melee_anim
	if weapon_type == WeaponType.COMPLEX_HILT_ONE_HAND:
		melee_anim = owner_character.find_node("SabreTechniques")
		if not melee_anim.is_playing():
			can_hit = true
			melee_anim.play("ThrustFromTierce")
			$Sounds/Thrust.play()
			yield(melee_anim, "animation_finished")
			character.stamina -= 50
			can_hit = false
			melee_anim.queue("RecoveryThrustToTierce")
	if weapon_type == WeaponType.POLEARM:
		melee_anim = owner_character.find_node("PolearmTechniques")
		if not melee_anim.is_playing():
			can_hit = true
			melee_anim.play("polearm_thrust_from_right")
			$Sounds/Thrust.play()
			yield(melee_anim, "animation_finished")
#			character.stamina -= 50 # this is bugged with halberd
			can_hit = false
			melee_anim.queue("polearm_recovery_from_right")


func attack_cut():
	character = get_parent().get_parent()
	var melee_anim
	if weapon_type == 3:
		melee_anim = owner_character.find_node("SabreTechniques")
		if not melee_anim.is_playing():
			can_hit = true
			melee_anim.play("Swing1FromTierce")
			$Sounds/Cut.play()
			yield(melee_anim, "animation_finished")
			character.stamina -= 50
			can_hit = false
			melee_anim.queue("Recovery1ToTierce")
	if weapon_type == 6:
		melee_anim = owner_character.find_node("PolearmTechniques")
		if not melee_anim.is_playing():
			can_hit = true
			melee_anim.play("polearm_cut_2") # WIP, AnimationPlayer got wiped during import_items merge
			$Sounds/Cut.play()
			yield(melee_anim, "animation_finished")
			character.stamina -= 50
			can_hit = false
			melee_anim.queue("polearm_cut_2_recovery") # WIP, AnimationPlayer got wiped during import_items merge


func _use_primary():
	if not on_cooldown:
		attack_thrust()
		$CooldownTimer.start(cooldown)
		on_cooldown = true
#		emit_signal("on_attack")  #not used at the moment; should be used to signal up to Animation Player and Hitbox?


func _use_secondary():
	if not on_cooldown:
		attack_cut()
		$CooldownTimer.start(cooldown)
		on_cooldown = true
#		emit_signal("on_attack")  #not used at the moment; should be used to signal up to Animation Player and Hitbox?


#
#	TODO: Changing the status of the weapon (dropping the weapon or unequiping it)
# while one of these timers is active should appropriately reset the timer and deal any of it's side effects
#
# currently if changed away from and changed back to melee weapon, first swing does nothing
#


# Make sure that this is always connected from each individual weapon's scene
func _on_CooldownTimer_timeout() -> void:
	on_cooldown = false


func _on_Hitbox_hit(other):
	if can_hit and other.owner != owner_character and other.owner.has_method("damage"):
		other.owner.damage(primary_damage1, primary_damage_type1, other)
		other.owner.damage(primary_damage2, primary_damage_type2, other)
		other.owner.damage(secondary_damage1, secondary_damage_type1, other)
		other.owner.damage(secondary_damage1, secondary_damage_type2, other)


func _on_Hitbox_body_entered(body):
	if primary_damage_type1 == 0:
		primary_damage1 / 2
	elif primary_damage_type2 == 0:
		primary_damage2 / 2
	elif secondary_damage_type1 == 0:
		secondary_damage1 / 2
	elif secondary_damage_type2 == 0:
		secondary_damage2 / 2
	
	# This pushes the hit object if it's a RigidBody
	if body is RigidBody and can_hit == true:
		body.apply_central_impulse(-character.global_transform.basis.z * primary_damage1)
		body.apply_central_impulse(-character.global_transform.basis.z * primary_damage2)
		body.apply_central_impulse(-character.global_transform.basis.z * secondary_damage1)
		body.apply_central_impulse(-character.global_transform.basis.z * secondary_damage2)
