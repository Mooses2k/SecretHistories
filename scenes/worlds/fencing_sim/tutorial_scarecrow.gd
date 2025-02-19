extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SignalBus.visibility_notifier_changed.connect(func(object: Node3D, visible_on_screen: bool):
		if object.name == "RopeViewDetector" and visible_on_screen == false:
			await get_tree().create_timer(.7).timeout
			visible = true
		)
