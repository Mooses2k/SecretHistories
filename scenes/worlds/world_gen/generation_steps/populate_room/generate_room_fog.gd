@tool
# Room fog volumes (issue #757, redesigned after the per-cell billboard fog was
# rejected in playtest: one puff cluster per cell read as a grid of fog pockets).
# Two-level dungeon weather model, decided by the parent atmosphere group:
# a special all-fog floor delivers one variant via `weather_scene_path` and it
# covers EVERY real room; a normal fog-type floor delivers per-room decisions
# via `room_paths` (RoomData -> scene path, empty string = clean room).
# Placement is ONE FogVolume per fogged room, sized from RoomData.rect2 so the
# fog fills the whole room interior continuously: a single volume has no grid
# pattern, and volumetric fog composites only up to the opaque surface depth,
# so the fog cannot bleed through walls (the original complaint).
# The volume grows a small margin horizontally into the surrounding 0.15 m
# walls and vertically into floor slab and ceiling line, so its geometric cut
# planes are buried inside opaque geometry; FogMaterial edge_fade keeps the
# visible boundaries soft. The volume centre and size travel with the SpawnData
# as custom properties applied after spawn, so anchor-cell relocation can never
# displace the fog.
# Non-invasive: one SpawnData per fogged room, anchored on the free cell
# nearest the room centre; draws no RNG so the generation seed stream is
# untouched. A room never mixes variants. Empty path means clean room: place
# nothing.
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

# Grown horizontally into the walls so the volume's cut planes are hidden
# inside wall geometry (wall pieces are 0.15 m thick).
const HORIZONTAL_WALL_MARGIN : float = 0.15
# Grown vertically into the floor slab and above the ceiling line.
const VERTICAL_SLAB_MARGIN : float = 0.2

#--- public variables - order: export > normal var > onready --------------------------------------

# Floor-wide variant, set once per run by GenerateAtmosphereGroup; non-empty
# on a special all-fog floor, empty on normal and dust floors.
@export var weather_scene_path := ""
# Per-room decisions on normal floors, keyed by RoomData; a room not in the
# dictionary falls back to `weather_scene_path`.
@export var room_paths := {}
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
	if weather_scene_path.is_empty() and room_paths.is_empty():
		return

	for room_value in data.get_all_rooms():
		var room := room_value as RoomData
		if room.type == WorldData.OriginalPurpose.EMPTY:
			continue
		var path: String = room_paths.get(room, weather_scene_path)
		if path.is_empty():
			continue

		_spawn_room_fog(data, room, path)


func _spawn_room_fog(data : WorldData, room : RoomData, path : String) -> void:
	var anchor_cell := _pick_anchor_cell(data, room)
	if anchor_cell < 0:
		return

	var spawn_data := SpawnData.new()
	spawn_data.scene_path = path
	spawn_data.amount = 1
	spawn_data.set_center_position_in_cell(CellFilter.get_cell_position(data, anchor_cell))
	spawn_data.set_custom_property("position", _room_volume_center(room))
	spawn_data.set_custom_property("size", _room_volume_size(room))
	data.set_object_spawn_data_to_cell(anchor_cell, spawn_data)


## Room interior bounds grown into the surrounding walls, floor slab and
## ceiling line, so every geometric edge of the fog volume sits inside opaque
## geometry. X/Z from RoomData.rect2 (cells), Y from the GridMap cell height.
func _room_volume_size(room : RoomData) -> Vector3:
	return Vector3(
		room.rect2.size.x * WorldData.CELL_SIZE + HORIZONTAL_WALL_MARGIN * 2.0,
		WorldData.WALL_SIZE + VERTICAL_SLAB_MARGIN * 2.0,
		room.rect2.size.y * WorldData.CELL_SIZE + HORIZONTAL_WALL_MARGIN * 2.0
	)


func _room_volume_center(room : RoomData) -> Vector3:
	return Vector3(
		room.rect2.position.x * WorldData.CELL_SIZE + room.rect2.size.x * WorldData.CELL_SIZE * 0.5,
		WorldData.WALL_SIZE * 0.5,
		room.rect2.position.y * WorldData.CELL_SIZE + room.rect2.size.y * WorldData.CELL_SIZE * 0.5
	)


## Free cell nearest the room centre, so the fog anchor never displaces item
## spawns other steps placed mid-room. Deterministic: draws no RNG.
func _pick_anchor_cell(data : WorldData, room : RoomData) -> int:
	var free_cells := CellFilter.filter_available_cells(data, room.cell_indexes)
	if free_cells.is_empty():
		return -1

	var center := _room_volume_center(room)
	var best_cell := free_cells[0] as int
	var best_distance := INF
	for cell_index in free_cells:
		var pos := CellFilter.get_cell_position(data, cell_index)
		var distance := Vector2(pos.x, pos.z).distance_squared_to(Vector2(center.x, center.z))
		if distance < best_distance:
			best_distance = distance
			best_cell = cell_index
	return best_cell

### -----------------------------------------------------------------------------------------------

### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
