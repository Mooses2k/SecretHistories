extends Position3D

export var threshold_angle_degrees = 60
onready var threshold_factor = cos(deg2rad(threshold_angle_degrees))
onready var fire: Spatial = $Fire
onready var light: Spatial = $Fire/Light

func _physics_process(delta):
	global_transform.basis = Basis.IDENTITY
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
