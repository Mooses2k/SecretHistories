@tool
# Room dust volumes (issue #757, wiring merged PRs #714 dust mote effects into generation).
# Dungeon weather rule: the whole run has ONE dust variant, chosen once by the
# parent atmosphere group and delivered via `weather_scene_path`. Empty path
# means no dust weather (fog run instead): place nothing, so fog and dust
# never coexist.
# Placement is a per-room single decision, never per-tile scattering:
# each room gets at most ONE dust volume, on one free cell.
# There is no light-shaft concept in dev4, so dust is spread by chance.
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

# Room types that can get dust. EMPTY is skipped.
const DUST_ROOM_TYPES := [
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
@export var accepts_fog_weather := false
@export var dust_room_chance := 0.35 # One dust volume in a fraction of rooms

#--- private variables - order: export > normal var > onready -------------------------------------

var _rng := RandomNumberGenerator.new()

### -----------------------------------------------------------------------------------------------

### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

### Private Methods -------------------------------------------------------------------------------

func _execute_step(data : WorldData, _gen_data : Dictionary, generation_seed : int):
	if weather_scene_path.is_empty():
		return

	_rng.seed = generation_seed

	for room_type in DUST_ROOM_TYPES:
		for room_value in data.get_rooms_of_type(room_type):
			var room := room_value as RoomData
			if _rng.randf() > dust_room_chance:
				continue

			var free_cells := CellFilter.filter_available_cells(data, room.cell_indexes)
			if free_cells.is_empty():
				continue

			var lucky_index := _rng.randi() % free_cells.size()
			var cell_index := free_cells[lucky_index] as int
			_spawn_dust_in_cell(data, cell_index)


func _spawn_dust_in_cell(data : WorldData, cell_index : int) -> void:
	var spawn_data := SpawnData.new()
	spawn_data.scene_path = weather_scene_path
	spawn_data.amount = 1
	spawn_data.set_center_position_in_cell(CellFilter.get_cell_position(data, cell_index))
	data.set_object_spawn_data_to_cell(cell_index, spawn_data)

### -----------------------------------------------------------------------------------------------

### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
