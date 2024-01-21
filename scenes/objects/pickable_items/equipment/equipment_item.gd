tool
class_name EquipmentItem
extends PickableItem


signal used_primary()
signal used_secondary()
signal used_reload()
signal used_unload()

export var can_attach : bool = false
export(GlobalConsts.ItemSize) var item_size : int = GlobalConsts.ItemSize.SIZE_MEDIUM

export var item_name : String = "Equipment"
export var horizontal_holding : bool = false
export var normal_pos_path : NodePath
export var throw_pos_path : NodePath

var is_in_belt : bool = false
var offhand_use_hold_time : float = 0.0
var mainhand_use_hold_time : float = 0.0

var use_hold_threshold  : float = 0.45

onready var hold_position = $"%HoldPosition"
onready var normal_pos = get_node(normal_pos_path)
onready var throw_pos = get_node(throw_pos_path)


func _ready():
	if horizontal_holding == true:
		hold_position.rotation_degrees.z = 90
		
	connect("body_entered", self, "play_drop_sound")


func _process(delta : float) -> void:
	if self.has_method("light"):
		if is_instance_valid(owner_character):
			if Input.is_action_pressed("playerhand|main_use_primary") and owner_character.is_reloading == false:
				mainhand_use_hold_time += 0.1
				if  mainhand_use_hold_time >= use_hold_threshold:
					if not get("is_lit"):
						call("light")
					if self == owner_character.inventory.get_mainhand_item():
						if horizontal_holding:
							owner_character.get_node("%AnimationTree").set("parameters/Hold_Animation/current", 2)
							owner_character.get_node("%AnimationTree").set("parameters/LightSourceHoldTransition/current", 0)
						else:
							owner_character.get_node("%AnimationTree").set("parameters/Hold_Animation/current", 2)
							owner_character.get_node("%AnimationTree").set("parameters/LightSourceHoldTransition/current", 2)

			else:
				if self == owner_character.inventory.get_mainhand_item():
					if horizontal_holding == true:
						owner_character.get_node("%AnimationTree").set("parameters/Hold_Animation/current", 1)
					else:
						owner_character.get_node("%AnimationTree").set("parameters/Hold_Animation/current", 0)

			if Input.is_action_pressed("playerhand|offhand_use") and owner_character.is_reloading == false:
				offhand_use_hold_time += 0.1
				if  offhand_use_hold_time >= use_hold_threshold :
					if not get("is_lit"):
						call("light")
					if self == owner_character.inventory.get_offhand_item():
						if horizontal_holding:
							owner_character.get_node("%AnimationTree").set("parameters/Offhand_Hold_Animation/current", 2)
							owner_character.get_node("%AnimationTree").set("parameters/OffhandLightSourceHoldTransition/current", 0)
						else:
							owner_character.get_node("%AnimationTree").set("parameters/Offhand_Hold_Animation/current", 2)
							owner_character.get_node("%AnimationTree").set("parameters/OffhandLightSourceHoldTransition/current", 2)
				
			else:
				offhand_use_hold_time = 0
				
				if self == owner_character.inventory.get_offhand_item():
					if horizontal_holding == true:
						owner_character.get_node("%AnimationTree").set("parameters/Offhand_Hold_Animation/current", 1)
					else:
						owner_character.get_node("%AnimationTree").set("parameters/Offhand_Hold_Animation/current", 0)
						

## WORKAROUND for https://github.com/godotengine/godot/issues/62435
# Bug here where when player rotates, items does a little circle thing in hand
func _physics_process(delta):
	if self.item_state == GlobalConsts.ItemState.EQUIPPED:
		##This checks if the item is a gun
		if self.get("ammunition_capacity") != null:
			transform = get_hold_transform()
		else:
			transform = get_hold_transform().inverse()


func apply_throw_logic():
	if thrown_point_first:
		print("Applying throw logic")
		self.global_rotation = throw_pos.global_rotation   # This attempts to align the point forward when throwing piercing weapons
	if can_spin:
		print("Item spins when thrown")
		angular_velocity = Vector3(global_transform.basis.x * -15)
#		angular_velocity.z = -15   # Ah, maybe not working because it's already been put in world_space at this point


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
	return $HoldPosition.transform
