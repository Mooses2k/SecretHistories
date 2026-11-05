@tool
# Room fog volumes (issue #757, wiring merged PRs #709/#714 effects into generation).
# PR #709 intent: the fog effects are meant to be tiled on a 1.5x size grid in rooms.
# WorldData.CELL_SIZE is 1.5, so that is one fog volume per room cell.
# Dungeon weather rule: the whole run has ONE fog variant, chosen once by the
# parent atmosphere group and delivered via `weather_scene_path`. A room never
# mixes variants. Empty path means no fog weather: place nothing.
# Non-invasive: additive SpawnData only, cells that are already occupied are skipped.
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

# Room types that get fog. EMPTY is skipped; fog covers every real room purpose.
const FOG_ROOM_TYPES := [
	RoomData.OriginalPurpose.CRYPT,
	RoomData.OriginalPurpose.FOUNTAIN,
	RoomData.OriginalPurpose.STATUE_GALLERY,
	RoomData.OriginalPurpose.UP_STAIRCASE,
	RoomData.OriginalPurpose.DOWN_STAIRCASE,
	RoomData.OriginalPurpose.TROPHY_ROOM,
]

#--- public variables - order: export > normal var > onready --------------------------------------

# Set once per run by GenerateAtmosphereGroup; empty disables this step.
@export var weather_scene_path := ""
# Declares this step's weather family to the parent group (fog vs dust).
@export var accepts_fog_weather := true

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------

### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

### Private Methods -------------------------------------------------------------------------------

func _execute_step(data : WorldData, _gen_data : Dictionary, _generation_seed : int):
	if weather_scene_path.is_empty():
		return

	for room_type in FOG_ROOM_TYPES:
		for room_value in data.get_rooms_of_type(room_type):
			var room := room_value as RoomData
			var free_cells := CellFilter.filter_available_cells(data, room.cell_indexes)
			for cell_index in free_cells:
				_spawn_fog_in_cell(data, cell_index)


func _spawn_fog_in_cell(data : WorldData, cell_index : int) -> void:
	var spawn_data := SpawnData.new()
	spawn_data.scene_path = weather_scene_path
	spawn_data.amount = 1
	spawn_data.set_center_position_in_cell(CellFilter.get_cell_position(data, cell_index))
	data.set_object_spawn_data_to_cell(cell_index, spawn_data)

### -----------------------------------------------------------------------------------------------

### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
