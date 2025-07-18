# Write your doc string for this file here
extends Node2D

#- Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const COLOR_PLAYER = Color.BLUE

#--- public variables - order: export > normal var > onready --------------------------------------

var player: Player = null
var font: Font = null

#--- private variables - order: export > normal var > onready -------------------------------------

#--------------------------------------------------------------------------------------------------


#- Built-in Virtual Overrides --------------------------------------------------------------------

func _ready() -> void:
	font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	if is_instance_valid(player) and visible:
		queue_redraw()


func _draw() -> void:
	if is_instance_valid(player) and visible:
		var radius: float = owner.distances_scale / 2.0
		var local_position: Vector2 = to_local(Vector2(
				player.global_position.x,
				player.global_position.z
		)) * owner.distances_scale / WorldData.CELL_SIZE
		draw_circle(local_position, owner.distances_scale / 2.0, COLOR_PLAYER)
		if owner.world_data:
			var cell_index : int = owner.world_data.get_cell_index_from_local_position(player.position)
			var text_position := local_position + Vector2(-0.8,0.5) * radius
			draw_string(font, text_position, str(cell_index), HORIZONTAL_ALIGNMENT_CENTER)

#--------------------------------------------------------------------------------------------------


#- Public Methods --------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------------------


#- Private Methods -------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------------------


#- Signal Callbacks ------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------------------
