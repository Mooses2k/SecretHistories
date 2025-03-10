class_name GamePlaceholder
extends Game

## Mainly so that it's easier to do standalone tests without things that need to access
## GameManager.game breaking.

#- Member Variables and Dependencies --------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

#--------------------------------------------------------------------------------------------------


#- Built-in Virtual Overrides ---------------------------------------------------------------------

func _ready():
	pass


func _input(_event: InputEvent) -> void:
	pass

#--------------------------------------------------------------------------------------------------


#- Public Methods ---------------------------------------------------------------------------------

func set_brightness():
	pass


func load_level(packed : PackedScene):
	pass


func spawn_player():
	pass

#--------------------------------------------------------------------------------------------------


#- Private Methods --------------------------------------------------------------------------------

func _connect_staircase_events() -> void:
	pass


func disconnect_staircase_events() -> void:
	pass

func _check_if_loading():
	pass

#--------------------------------------------------------------------------------------------------


#- Signal Callbacks -------------------------------------------------------------------------------

func _on_first_level_loaded(_level : GameWorld):
	pass


func _handle_floor_change(is_going_downstairs: bool) -> void:
	pass


func _show_load_screen() -> void:
	pass


func _handle_floor_levels() -> void:
	pass


func _set_new_position_for_player(is_going_downstairs: bool) -> void:
	pass


func _on_Events_up_staircase_used() -> void:
	pass


func _on_Events_down_staircase_used() -> void:
	pass

#--------------------------------------------------------------------------------------------------
