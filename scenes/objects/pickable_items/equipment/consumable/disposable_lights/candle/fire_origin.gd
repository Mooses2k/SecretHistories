extends Position3D


export var threshold_angle_degrees = 60

var toppled = false

onready var threshold_factor = cos(deg2rad(threshold_angle_degrees))
onready var fire: Spatial = $Fire
onready var light: Spatial = $Fire/Light


func _ready():
	global_transform.basis = Basis.IDENTITY


func _physics_process(delta):
#	global_transform.basis = Basis.IDENTITY
	handle_toppled_light()


func handle_toppled_light():
	if owner is TorchItem:
		return
	# Tracks if if it's toppled, so it can still be lit when toppled
	if owner.global_transform.basis.y.normalized().y < threshold_factor and !toppled:
		if owner is PickableItem and owner.item_state == GlobalConsts.ItemState.EQUIPPED:
			return
		if owner.has_method("unlight"):
			owner.unlight()
			if !owner is LanternItem:   # The effect of this is that you can't light an toppled lantern, because of common safety features on them
				toppled = true
				# TODO: make it randomly go out after awhile and/or speed up burntime if it's burning while lying on side?
		# TODO Implement a better way for light sources without unlight method
		else:
			if is_instance_valid(fire):
				fire.visible = false
			if is_instance_valid(light):
				light.visible = false
	if !owner.global_transform.basis.y.normalized().y < threshold_factor and toppled:
		toppled = false
