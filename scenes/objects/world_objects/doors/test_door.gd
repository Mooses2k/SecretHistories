extends Area

export var active_material : Material
export var inactive_material : Material

var active = true setget set_active
var navigation : Navigation
var navmesh : NavigationMeshInstance

var active_transform = Transform.IDENTITY
var inactive_transform = Transform(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)

func set_active(value : bool):
	$Visual.material_override = active_material if value else inactive_material
	navmesh.enabled = value
	active = value

func _ready():
	self.active = true
	pass


func _on_TestDoor_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		self.active = !self.active
	pass # Replace with function body.
