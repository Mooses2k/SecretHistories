extends EquipmentItem
class_name MeleeItem


export var melee_damage = 0
export var cooldown = 0.01

export(AttackTypes.Types) var melee_damage_type : int = 0

onready var melee_hitbox = $Hitbox

var on_cooldown = false

func attack():
	var melee_anim = owner_character.find_node("AnimationPlayer")  # this needs to set only when equipped
	# need something here to determine type of weapon, for now, a sabre
	if not melee_anim.is_playing():    #how to correctly point to this?
		melee_anim.play("Swing1FromTierce")
		melee_anim.queue("RecoveryToTierce")
	if melee_anim.current_animation == "Swing1FromTierce":
		for area in melee_hitbox.get_overlapping_areas():
			print("hit an area")  
			if area.is_in_group("CHARACTER") or area is Hitbox:
				print("hit a character!") # never procs
#				area.current_health -= melee_damage    # crashes it
				area.hit(melee_damage, AttackTypes.Types.PHYSICAL) # doesn't kill
				
func _use():
	print("try use : ", on_cooldown, " ")
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
	pass # Replace with function body.
