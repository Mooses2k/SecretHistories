extends EquipmentItem
class_name MeleeItem


enum WeaponType {
	ROCK,
	KNIFE,
	SIMPLE_HILT_ONE_HAND,
	COMPLEX_HILT_ONE_HAND,
	TWO_HANDED_SWORD,
	AXE_AND_SLEDGE,
	POLEARM,
	COUNT
}

export(WeaponType) var weapon_type : int = 0
export var melee_damage = 0
export var cooldown = 0.01

export(AttackTypes.Types) var melee_damage_type : int = 0
onready var melee_hitbox = $Hitbox as Area

var can_hit = false
var on_cooldown = false


func _ready():
	if melee_damage_type==1:
		melee_damage/2
	else:
		melee_damage=melee_damage


# Should be: Left-Click thrust, Right-Click cut, when nothing else, guard. Each attack has a recovery animation, but technically a thrust from one side should be able to recover to any of the guards
func attack():
	var melee_anim
	if weapon_type == 3:
		melee_anim = owner_character.find_node("SabreTechniques")
	if weapon_type == 6:
		melee_anim = owner_character.find_node("PolearmTechniques")
	else:
		pass
	# need something here to determine type of weapon, for now, a sabre
	#determine attack angle from where pointing
	if not melee_anim.is_playing(): 
		can_hit = true
		melee_anim.play("Swing1FromTierce")
		yield(melee_anim, "animation_finished")
		can_hit = false
		melee_anim.queue("Recovery1ToTierce")


func _use_primary():
	if not on_cooldown:
		attack()
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
