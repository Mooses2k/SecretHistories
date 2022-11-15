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
export var melee_damage = 0
export var cooldown = 0.01
export var can_Spin : bool
export var throw_logic : bool

export var element_path : NodePath
onready var collision_and_mesh = get_node(element_path)
export var normal_pos_path : NodePath
onready var normal_pos = get_node(normal_pos_path)
export var throw_pos_path : NodePath
onready var throw_pos = get_node(throw_pos_path)

export(AttackTypes.Types) var melee_damage_type : int = 0
onready var melee_hitbox = $Hitbox as Area

var can_hit = false
var on_cooldown = false
#
#export (NodePath) var player_path
#
#onready var player = get_node(player_path)

onready var character = get_parent()


func _ready():
	pass

func _process(delta):
	if throw_logic == true :
		if item_state == GlobalConsts.ItemState.EQUIPPED: 
			collision_and_mesh.global_transform.origin = normal_pos.global_transform.origin
			collision_and_mesh.global_rotation = normal_pos.global_rotation


# Should be: Left-Click thrust, Right-Click cut, when nothing else, guard. Each attack has a recovery animation, but technically a thrust from one side should be able to recover to any of the guards
func attack_thrust():
	character = get_parent().get_parent().get_parent()
	var melee_anim
	if weapon_type == 3:
		melee_anim = owner_character.find_node("SabreTechniques")
		if not melee_anim.is_playing():
			can_hit = true
			melee_anim.play("ThrustFromTierce")
			yield(melee_anim, "animation_finished")
			character.stamina -= 50
			can_hit = false
			melee_anim.queue("RecoveryThrustToTierce")
	if weapon_type == 6:
		melee_anim = owner_character.find_node("PolearmTechniques")
		if not melee_anim.is_playing():
			can_hit = true
			melee_anim.play("polearm_thrust_from_right")
			yield(melee_anim, "animation_finished")
#			character.stamina -= 50 # this is bugged with halberd
			can_hit = false
			melee_anim.queue("polearm_recovery_from_right")

	# need something here to determine type of weapon, for now, a sabre
	#determine attack angle from where pointing

func apply_throw_logic(impulse):
	if throw_logic:
		collision_and_mesh.global_transform.origin = throw_pos.global_transform.origin
		collision_and_mesh.global_rotation = throw_pos.global_rotation
	if can_Spin:
		angular_velocity = Vector3(global_transform.basis.z*30)
		apply_central_impulse(impulse)
	else:
		apply_central_impulse(impulse)


func attack_cut():
	character = get_parent().get_parent().get_parent()
	var melee_anim
	if weapon_type == 3:
		melee_anim = owner_character.find_node("SabreTechniques")
		if not melee_anim.is_playing():
			can_hit = true
			melee_anim.play("Swing1FromTierce")
			yield(melee_anim, "animation_finished")
			character.stamina -= 50
			can_hit = false
			melee_anim.queue("Recovery1ToTierce")
	if weapon_type == 6:
		melee_anim = owner_character.find_node("PolearmTechniques")
		if not melee_anim.is_playing():
			can_hit = true
			melee_anim.play("polearm_cut_2") # WIP
			yield(melee_anim, "animation_finished")
			character.stamina -= 50
			can_hit = false
			melee_anim.queue("polearm_cut_2_recovery") # WIP


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


func _on_CooldownTimer_timeout() -> void:
	on_cooldown = false


func _on_Hitbox_hit(other):
	if can_hit and other.owner != owner_character and other.owner.has_method("damage"):
		other.owner.damage(melee_damage, melee_damage_type, other)


func _on_Hitbox_body_entered(body):
	if melee_damage_type == 0:
		melee_damage / 2
	else:
		melee_damage = melee_damage
	if body is RigidBody and can_hit == true:
		body.apply_central_impulse(-character.global_transform.basis.z * melee_damage)
