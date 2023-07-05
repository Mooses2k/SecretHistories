# Write your doc string for this file here
extends Camera

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

export var move_speed := 10

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == BUTTON_WHEEL_UP:
			translation.y -= 1
		elif mouse_event.button_index == BUTTON_WHEEL_DOWN:
			translation.y += 1


func _physics_process(delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_direction != Vector2.ZERO:
		var move_direction := Vector3(input_direction.x, 0, input_direction.y)
		var ground_speed := Vector3(move_speed, 1, move_speed)
		var final_position := translation + move_direction
		translation = translation.move_toward(final_position, delta * move_speed)


### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
