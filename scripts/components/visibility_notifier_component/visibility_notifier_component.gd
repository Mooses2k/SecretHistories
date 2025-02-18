extends Node3D
class_name VisibilityNotifierComponent

var visibility_notifier_node: VisibleOnScreenNotifier3D

func _ready() -> void:
	visibility_notifier_node = VisibleOnScreenNotifier3D.new()
	add_child(visibility_notifier_node)
	
	visibility_notifier_node.screen_entered.connect(func():
		var visible_on_screen = true
		var caller_object = get_parent()
		SignalBus.emit_visibility_notifier_changed(caller_object, visible_on_screen)
		)
	
	visibility_notifier_node.screen_exited.connect(func():
		var visible_on_screen = false
		var caller_object = get_parent()
		SignalBus.emit_visibility_notifier_changed(caller_object, visible_on_screen)
	)
