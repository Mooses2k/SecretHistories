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

@export_subgroup("Stacking")
@export var stackable_resource: StackableResource

## Stack record link: id of the StackableStackRecord this node represents in
## its owner's Inventory, or -1 when the node is not a stack representative.
var stack_record_id : int = -1

var is_in_belt : bool = false

var _is_action_held : bool = false

@onready var hold_position = %HoldPosition


func _ready():
	if hold_position == null:
		# %HoldPosition only resolves when the scene's HoldPosition node has
		# unique_name_in_owner = true. A missing marker used to be a per-spawn
		# node-not-found error plus a mid-equip crash in get_hold_transform(),
		# which stranded Inventory.current_mainhand_equipment with an empty
		# hand. Warn once per spawn instead of erroring every equip.
		push_warning("EquipmentItem '%s' has no HoldPosition marker, equip pose falls back to identity" % name)
	elif horizontal_holding == true:
		hold_position.rotation_degrees.z = 90


## WORKAROUND for https://github.com/godotengine/godot/issues/62435
# Bug here where when player rotates, items does a little circle thing in hand
# Minimum documented workaround (audit Finding 4.8), so the future component
# rework can remove it deliberately:
# - The transform being asserted every physics frame is the EQUIPPED ITEM's
#   local transform relative to the hand root the item is parented to.
# - HoldPosition is authored in ITEM-LOCAL space. For non-guns it marks the
#   grip point, so the item pose that puts the grip exactly on the hand root
#   origin is the INVERSE of the marker transform: T * H = identity means
#   T = HoldPosition.transform.inverse().
# - For guns, HoldPosition is authored as the desired full item pose relative
#   to the hand root instead, so the raw marker transform is used.
# - The per-frame rewrite is what compensates for godot#62435: without it the
#   equipped item slowly orbits ("does a little circle") in the hand while the
#   player rotates, because the body's pose drifts between physics ticks.
# The former duck-typed gun check (self.get("ammunition_capacity") != null)
# was equivalent to `is GunItem`: gun_item.gd is the only script defining
# ammunition_capacity.
func _physics_process(delta):
	super._physics_process(delta)
	if self.item_state == GlobalConsts.ItemState.EQUIPPED:
		##This checks if the item is a gun
		if self is GunItem:
			transform = get_hold_transform()
		else:
			transform = get_hold_transform().inverse()


func apply_throw_logic(direction : Vector3 = Vector3.ZERO):
	if thrown_point_first:
		var throw_basis : Basis = Basis.IDENTITY
		if not direction.is_equal_approx(Vector3.UP):
			throw_basis.y = direction.normalized()
			throw_basis.x = throw_basis.y.cross(Vector3.UP).normalized()
			throw_basis.z = throw_basis.x.cross(throw_basis.y)
		self.global_basis = throw_basis # This attempts to align the point forward when throwing piercing weapons
	if can_spin:
		angular_velocity = Vector3(global_transform.basis.x * -15)
#		angular_velocity.z = -15   # Ah, maybe not working because it's already been put in world_space at this point


# Override this function for (LMB mainhand, LAlt offhand) tap-to-use actions.
# Stack consumption used to pop the legacy array here; consumption now goes
# through the owning Inventory's record API, so the base body is empty.
func _use_primary():
	pass


#TODO remove secondary use, replace with held use
# Override this function for (LMB mainhand, LAlt offhand) hold-to-use actions
func _use_secondary():
	pass


func use_primary():
	_use_primary()
	emit_signal("used_primary")


func use_secondary():
	_use_secondary()
	emit_signal("used_secondary")


# Reloads can only happen in main-hand, currently
func _use_reload():
	pass


# Unloads all ammo
func _use_unload():
	pass


func use_reload():
	_use_reload()
	emit_signal("used_reload")


func use_unload():
	_use_unload()
	emit_signal("used_unload")


func _set_held_use(enabled : bool) -> void:
	pass


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
	if hold_position == null:
		return Transform3D.IDENTITY
	return hold_position.transform
