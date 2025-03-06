extends Node

signal visibility_notifier_changed(object: Node3D, visible_on_screen: bool)

# Fencing Sim Signals
signal candle_unlit(candle: CandleItem)

## This function can be used to emit visibility_notifier_changed with type safety
func emit_visibility_notifier_changed(object: Node3D, visible_on_screen: bool) -> void:
	visibility_notifier_changed.emit(object, visible_on_screen)
