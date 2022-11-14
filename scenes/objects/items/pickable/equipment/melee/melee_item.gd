extends EquipmentItem
class_name MeleeItem


export var melee_damage = 0
export var cooldown = 0.01
export var Can_Spin : bool
export var Throw_logic : bool

export var Throw_pos_path : NodePath
onready var Throw_Pos = get_node(Throw_pos_path)
export var Normal_pos_path : NodePath
onready var Normal_Pos = get_node(Normal_pos_path)

export(AttackTypes.Types) var melee_damage_type : int = 0
onready var melee_hitbox = $Hitbox as Area



export var Element_path : NodePath
onready var Elements = get_node(Element_path)




var can_hit = false
var on_cooldown = false


func _ready():
	if Throw_logic == true :
		if item_state == GlobalConsts.ItemState.EQUIPPED: 
			Elements.global_transform.origin = Normal_Pos.global_transform.origin
			Elements.global_rotation = Normal_Pos.global_rotation

		elif item_state == GlobalConsts.ItemState.DROPPED:
			Elements.global_transform.origin = Throw_Pos.global_transform.origin
			Elements.global_rotation = Throw_Pos.global_rotation

	if melee_damage_type == 1:
		melee_damage/2
	else:
		melee_damage = melee_damage

func _process(delta):
	if Throw_logic == true :
		if item_state == GlobalConsts.ItemState.EQUIPPED: 
			Elements.global_transform.origin = Normal_Pos.global_transform.origin
			Elements.global_rotation = Normal_Pos.global_rotation

		elif item_state == GlobalConsts.ItemState.DROPPED:
			Elements.global_transform.origin = Throw_Pos.global_transform.origin
			Elements.global_rotation = Throw_Pos.global_rotation

	
	
	
	
	
# Should be: Left-Click thrust, Right-Click cut, when nothing else, guard. Each attack has a recovery animation, but technically a thrust from one side should be able to recover to any of the guards
func attack(): # bug is it only checks for hit right when attack is first called, needs to check as long as in melee_anim "Swing"
	var melee_anim = owner_character.find_node("AnimationPlayer")  # this needs to set only when equipped
	# need something here to determine type of weapon, for now, a sabre
	#determine attack angle from where pointing
	if not melee_anim.is_playing(): 
		can_hit = true
		melee_anim.play("Swing1FromTierce")
		yield(melee_anim, "animation_finished")
		can_hit = false
		melee_anim.queue("Recovery1ToTierce")

func apply_throw_logic(impulse):
	if Can_Spin:
		angular_velocity = Vector3(global_transform.basis.z*30)
		apply_central_impulse(impulse /1.5)

	else:
		apply_central_impulse(impulse /1.5)


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
