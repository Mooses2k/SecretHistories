@tool
# Room dust volumes (issue #757, wiring merged PRs #714 dust mote effects into generation).
# Two-level dungeon weather model, decided by the parent atmosphere group:
# a special all-dust floor delivers one variant via `weather_scene_path` and it
# covers EVERY real room; a normal dust-type floor delivers per-room decisions
# via `room_paths` (RoomData -> scene path, empty string = clean room).
# Placement is a per-room single decision, never per-tile scattering:
# each room gets at most ONE dust volume, on one free cell.
# There is no light-shaft concept in dev4, so dust is spread by chance.
# Empty path means clean room: place nothing, so fog and dust never coexist.
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------

# Floor-wide variant, set once per run by GenerateAtmosphereGroup; non-empty
# on a special all-dust floor, empty on normal and fog floors.
@export var weather_scene_path := ""
# Per-room decisions on normal floors, keyed by RoomData; a room not in the
# dictionary falls back to `weather_scene_path`.
@export var room_paths := {}
# Declares this step's weather family to the parent group (fog vs dust).
@export var accepts_fog_weather := false

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------

### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

### Private Methods -------------------------------------------------------------------------------

func _execute_step(data : WorldData, _gen_data : Dictionary, _generation_seed : int):
	if weather_scene_path.is_empty() and room_paths.is_empty():
		return

	for room_value in data.get_all_rooms():
		var room := room_value as RoomData
		if room.type == RoomData.OriginalPurpose.EMPTY:
			continue
		var path: String = room_paths.get(room, weather_scene_path)
		if path.is_empty():
			continue

		var free_cells := CellFilter.filter_available_cells(data, room.cell_indexes)
		if free_cells.is_empty():
			continue

		var lucky_index := randi() % free_cells.size()
		var cell_index := free_cells[lucky_index] as int
		_spawn_dust_in_cell(data, cell_index, path)


func _spawn_dust_in_cell(data : WorldData, cell_index : int, path : String) -> void:
	var spawn_data := SpawnData.new()
	spawn_data.scene_path = path
	spawn_data.amount = 1
	spawn_data.set_center_position_in_cell(CellFilter.get_cell_position(data, cell_index))
	data.set_object_spawn_data_to_cell(cell_index, spawn_data)

### -----------------------------------------------------------------------------------------------

### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
