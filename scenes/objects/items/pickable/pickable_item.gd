extends RigidBody
class_name PickableItem

signal picked_up()
signal dropped()

var _owner : Node = null
onready var mesh_instance = $MeshInstance
onready var collision_shape = $CollisionShape

func can_pickup(by : Node) -> bool:
	return _owner == null

func pickup(by : Node) -> RigidBody:
	emit_signal("picked_up")
	get_parent().remove_child(self)
	collision_shape.disabled = true
	self._owner = by
	return self

func drop(at : Transform):
	emit_signal("dropped")
	if self.get_parent():
		get_parent().remove_child(self)
	self._owner = null
	collision_shape.disabled = false
	if GameManager.game.level:
		self.global_transform = at
		GameManager.game.level.add_child(self)
	else:
		printerr(self, " has disappeared into the void: no Level was found")
		self.queue_free()

func has_instance_data() -> bool:
	return false

func get_instance_data() -> Dictionary:
	return Dictionary()

func set_instance_data(value : Dictionary):
	pass
