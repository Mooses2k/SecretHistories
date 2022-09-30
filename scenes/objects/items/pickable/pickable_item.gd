extends RigidBody
class_name PickableItem

signal item_state_changed(previous_state, current_state)

export(int, LAYERS_3D_PHYSICS) var dropped_layers : int = 0
export(int, LAYERS_3D_PHYSICS) var dropped_mask : int = 0
export(int, "Rigid", "Static", "Character", "Kinematic") var dropped_mode : int = MODE_RIGID

export(int, LAYERS_3D_PHYSICS) var equipped_layers : int = 0
export(int, LAYERS_3D_PHYSICS) var equipped_mask : int = 0
export(int, "Rigid", "Static", "Character", "Kinematic") var equipped_mode : int = MODE_KINEMATIC

export var max_speed : float = 12.0
#export(int, LAYERS_3D_PHYSICS) var dropped_layers : int
#export(int, LAYERS_3D_PHYSICS) var dropped_mask : int
#export(int, "Rigid", "Static", "Character", "Kinematic") var dropped_mode : int
#
#export(int, LAYERS_3D_PHYSICS) var equipped_layers
#export(int, LAYERS_3D_PHYSICS) var equipped_mask
#export(int, "Rigid", "Static", "Character", "Kinematic") var equipped_mode : int





#onready var mesh_instance = $MeshInstance
var owner_character : Node = null
var item_state = GlobalConsts.ItemState.DROPPED setget set_item_state


func _enter_tree():
	match self.item_state:
		GlobalConsts.ItemState.DROPPED:	
			set_physics_dropped()
		GlobalConsts.ItemState.INVENTORY:
			set_physics_equipped()
		GlobalConsts.ItemState.EQUIPPED:
			set_physics_equipped()

func set_item_state(value : int) :
	var previous = item_state
	item_state = value
	emit_signal("item_state_changed", previous, item_state)

func set_physics_dropped():
	self.collision_layer = dropped_layers
	self.collision_mask = dropped_mask
	self.mode = dropped_mode

func set_physics_equipped():
	self.collision_layer = equipped_layers
	self.collision_mask = equipped_mask
	self.mode = equipped_mode
#
func _integrate_forces(state):
	if item_state == GlobalConsts.ItemState.DROPPED:
		state.linear_velocity = state.linear_velocity.normalized()*min(state.linear_velocity.length(), max_speed)
#func pickup(by : Node):
#	self.item_state = ItemState.INVENTORY
#	if self.is_inside_tree():
#		get_parent().call_deferred("remove_child", self)
#		yield(self, "tree_exited")
#	set_physics_equipped()
#	self.owner_character = by

#func drop(at : Transform):
#	self.item_state = ItemState.DROPPED
#	if self.get_parent():
#		get_parent().call_deferred("remove_child", self)
#		yield(self, "tree_exited")
#	set_physics_dropped()
#	self.owner_character = null
#	if GameManager.game.level:
#		self.global_transform = at
##		self.linear_velocity = at.basis.x
#		GameManager.game.level.call_deferred("add_child", self)
#		yield(self, "tree_entered")
#		self.force_update_transform()
#	else:
#		printerr(self, " has disappeared into the void: no Level was found")
#		self.free()
