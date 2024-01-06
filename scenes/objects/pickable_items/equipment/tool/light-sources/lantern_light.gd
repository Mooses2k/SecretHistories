extends Spatial

# This code is duplicated from "res://scenes/objects/pickable_items/equipment/consumable/disposable_lights/candle/fire_origin.gd"


export var threshold_angle_degrees = 60

onready var threshold_factor = cos(deg2rad(threshold_angle_degrees))


func _physics_process(delta: float) -> void:
	handle_toppled_light()


func handle_toppled_light():
	if owner.global_transform.basis.y.normalized().y < threshold_factor:
		if owner.item_state == GlobalConsts.ItemState.EQUIPPED:
			return
		if owner.has_method("unlight"):
			owner.unlight()
