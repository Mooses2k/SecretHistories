class_name EquipmentItem
extends PickableItem


signal used_primary()
signal used_secondary()
signal held_use_toggled(enabled : bool)
signal held_use_enabled()
signal held_use_disabled()
signal used_reload()
signal used_unload()

@export var can_attach : bool = false
@export var item_size : GlobalConsts.ItemSize = GlobalConsts.ItemSize.SIZE_MEDIUM # (GlobalConsts.ItemSize)

@export var item_name : String = "Equipment"
@export var horizontal_holding : bool = false
@export var throw_pos_path : NodePath

@export_subgroup("Stacking")
@export var stackable_resource: StackableResource

var is_in_belt = false

var _is_action_held : bool = false

@onready var hold_position = %HoldPosition
@onready var throw_pos = get_node(throw_pos_path)


func _ready():
	if horizontal_holding == true:
		hold_position.rotation_degrees.z = 90

	connect("body_entered", Callable(self, "play_drop_sound"))


## WORKAROUND for https://github.com/godotengine/godot/issues/62435
# Bug here where when player rotates, items does a little circle thing in hand
func _physics_process(delta):
	if self.item_state == GlobalConsts.ItemState.EQUIPPED:
		##This checks if the item is a gun
		if self.get("ammunition_capacity") != null:
			transform = get_hold_transform()
		else:
			transform = get_hold_transform().inverse()
	elif self.item_state == GlobalConsts.ItemState.DAMAGING:
		# Check if the item has come to rest after being thrown
		# If linear velocity is below threshold, transition to DROPPED state
		var velocity_threshold = 0.1  # Adjust this value as needed
		if linear_velocity.length() < velocity_threshold and angular_velocity.length() < velocity_threshold:
			print("Item has come to rest, transitioning from DAMAGING to DROPPED")
			set_item_state(GlobalConsts.ItemState.DROPPED)


func apply_throw_logic(direction : Vector3 = Vector3.ZERO):
	if thrown_point_first:
		print("Applying throw logic")
		var throw_basis : Basis = Basis.IDENTITY
		if not direction.is_equal_approx(Vector3.UP):
			throw_basis.y = direction.normalized()
			throw_basis.x = throw_basis.y.cross(Vector3.UP).normalized()
			throw_basis.z = throw_basis.x.cross(throw_basis.y)
		self.global_basis = throw_basis # This attempts to align the point forward when throwing piercing weapons
		#self.global_rotation = throw_pos.global_rotation   
	if can_spin:
		print("Item spins when thrown")
		angular_velocity = Vector3(global_transform.basis.x * -15)
#		angular_velocity.z = -15   # Ah, maybe not working because it's already been put in world_space at this point


# Override this function for (LMB mainhand, LAlt offhand) tap-to-use actions
func _use_primary():
	print("use primary")
	if stackable_resource != null:
		if stackable_resource.items_stacked.size() > 0:
			stackable_resource.items_stacked.pop_front()
	pass


#TODO remove secondary use, replace with held use
# Override this function for (LMB mainhand, LAlt offhand) hold-to-use actions
func _use_secondary():
	print("use secondary")
	if stackable_resource != null:
		if stackable_resource.items_stacked.size() > 0:
			stackable_resource.items_stacked.pop_front()
	pass


func use_primary():
	_use_primary()
	emit_signal("used_primary")


func use_secondary():
	_use_secondary()
	emit_signal("used_secondary")


# Reloads can only happen in main-hand, currently
func _use_reload():
	print("use reload")
	pass


# Unloads all ammo
func _use_unload():
	print("use unload")
	pass


func use_reload():
	_use_reload()
	emit_signal("used_reload")


func use_unload():
	_use_unload()
	emit_signal("used_unload")


func _set_held_use(enabled : bool) -> void:
	print("Held action set to: ", "enabled" if enabled else "disabled")


func _has_held_use() -> bool:
	return false


func set_held_use(enabled : bool) -> void:
	_set_held_use(enabled)
	_is_action_held = enabled
	if enabled:
		held_use_enabled.emit()
	else:
		held_use_disabled.emit()
	held_use_toggled.emit(enabled)


func is_held():
	return _is_action_held


func has_held_use():
	return _has_held_use()


func get_hold_transform() -> Transform3D:
	return $HoldPosition.transform
