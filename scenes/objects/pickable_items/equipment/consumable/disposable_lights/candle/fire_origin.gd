extends Marker3D


@export var threshold_angle_degrees = 60

@onready var threshold_factor = cos(deg_to_rad(threshold_angle_degrees))
@onready var fire: Node3D = $Fire
@onready var light: Node3D = $Fire/Light3D


func _physics_process(delta):
	global_transform.basis = Basis.IDENTITY
	if !owner.sleeping:   # For performance, unknown impact
		handle_toppled_light()


func handle_toppled_light():
	if owner is TorchItem:
		return
	if owner.global_transform.basis.y.normalized().y < threshold_factor:
		if owner is PickableItem and owner.item_state == GlobalConsts.ItemState.EQUIPPED:
			return
		if owner.has_method("unlight"):
			owner.unlight()
		# TODO Implement a better way for light sources without unlight method
		else:
			if is_instance_valid(fire):
				fire.visible = false
			if is_instance_valid(light):
				light.visible = false
