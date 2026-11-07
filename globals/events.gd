# Autoload just for signals that help connect different parts of the game in a decoupled way
# More info: https://www.gdquest.com/tutorial/godot/design-patterns/event-bus-singleton/
extends Node


signal up_staircase_used
signal down_staircase_used

# parameters are values from GameManager.ScreenFilter enum
signal debug_filter_forced(screen_filter)

# Emitted when the player's ears should ring: the ghost damage area emits per
# frame while the player overlaps (strength = frame delta), the player's own
# gunshots emit their normalized loudness (gun_item.gd). Consumed by the
# tinnitus overlay in scenes/ui.
signal tinnitus_triggered(strength : float)

func connect_to(
		signal_name: String, 
		object: Object, 
		callback_name: String,
		binds := [],
		flags := 0
) -> void:
	if not is_connected(signal_name, Callable(object, callback_name)):
		var error := connect(signal_name, Callable(object, callback_name).bind(binds), flags)
		if error != OK:
			push_error("Failed to connect %s to %s.%s | Error code: %s"%[
				signal_name, object, callback_name, error
			])


func disconnect_from(signal_name: String, object: Object, callback_name: String) -> void:
	if is_connected(signal_name, Callable(object, callback_name)):
		disconnect(signal_name, Callable(object, callback_name))
