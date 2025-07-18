# Autoload just for signals that help connect different parts of the game in a decoupled way
# More info: https://www.gdquest.com/tutorial/godot/design-patterns/event-bus-singleton/
extends Node


signal up_staircase_used
signal down_staircase_used

# parameters are values from GameManager.ScreenFilter enum
signal debug_filter_forced(screen_filter)
