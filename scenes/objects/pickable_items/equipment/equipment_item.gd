tool
class_name EquipmentItem
extends PickableItem


signal used_primary()
signal used_secondary()
signal used_reload()
signal used_unload()

export (bool) var can_attach = false
export(GlobalConsts.ItemSize) var item_size : int = GlobalConsts.ItemSize.SIZE_MEDIUM

export var item_name : String = "Equipment"
export var horizontal_holding : bool = false
export var normal_pos_path : NodePath
export var throw_pos_path : NodePath
export var throw_logic : bool   # Some items like swords should be thrown point first; TODO: name better like thrown_point_first
export var can_spin : bool   # Some items should spin when thrown

var is_in_belt = false

onready var hold_position = $"%HoldPosition"
onready var normal_pos = get_node(normal_pos_path)
onready var throw_pos = get_node(throw_pos_path)


func _ready():
	if horizontal_holding == true:
		hold_position.rotation_degrees.z = 90
		
	connect("body_entered", self, "play_drop_sound")


## WORKAROUND for https://github.com/godotengine/godot/issues/62435
# Bug here where when player rotates, items does a little circle thing in hand
func _physics_process(delta):
	if self.item_state == GlobalConsts.ItemState.EQUIPPED:
		transform = get_hold_transform()
	
	if !is_instance_valid(owner_character):   # this is still hacky, but don't do throw damage if grabbing, basically
		throw_damage(delta)


func throw_damage(delta):
	if can_throw_damage:
		
		var bodies = get_colliding_bodies()
		if has_thrown == false:
			initial_linear_velocity = linear_velocity.z
			has_thrown = true
		
		for body_found in bodies:
			if body_found.is_in_group("CHARACTER"):
				var item_damage = int(abs(initial_linear_velocity)) * mass
				if not is_higher_damage :
					if item_damage > 5:
						item_damage = 2
				print("Damage inflicted on: ", body_found.name, " is: ", item_damage)
				body_found.damage(item_damage, melee_damage_type, body_found)
				can_throw_damage = false
				has_thrown = false
				decelerate_item_velocity(delta, true)
				set_item_state(GlobalConsts.ItemState.DROPPED)
			else:
				has_thrown = false
				can_throw_damage = false
#				decelerate_item_velocity(delta, true)   # Causes glitches like thrown objects sticking in arched wall collisions
				set_item_state(GlobalConsts.ItemState.DROPPED)


func decelerate_item_velocity(delta, decelerate):
	if !TinyItem:
		if self.item_size == GlobalConsts.ItemSize.SIZE_SMALL:
			if decelerate == true:
				print("decelerating item")
				linear_velocity *= 0


# TODO: needs commenting and probably fixing, is a messs
func implement_throw_damage(higher_damage):
	is_higher_damage = higher_damage
	can_throw_damage = true
	play_throw_sound()


# Override this function for (Left-Click and E, typically) use actions
func _use_primary():
	print("use primary")
	pass


# Right-click, typically
func _use_secondary():
	print("use secondary")
	pass


# Reloads can only happen in main-hand
func _use_reload():
	print("use reload")
	pass


func _use_unload():
	print("use unload")
	pass


func use_primary():
	_use_primary()
	emit_signal("used_primary")


func use_secondary():
	_use_secondary()
	emit_signal("used_secondary")


func use_reload():
	_use_reload()
	emit_signal("used_reload")


func use_unload():
	_use_unload()
	emit_signal("used_unload")


func get_hold_transform() -> Transform:
	return $HoldPosition.transform.inverse()


func apply_throw_logic():
	if throw_logic:
		print("Applying throw logic")
		self.global_rotation = throw_pos.global_rotation   # This attempts to align the point forward when throwing piercing weapons
	if can_spin:
		angular_velocity = Vector3(global_transform.basis.x * -15)
#		angular_velocity.z = -15   # Ah, maybe not working because it's already been put in world_space at this point
