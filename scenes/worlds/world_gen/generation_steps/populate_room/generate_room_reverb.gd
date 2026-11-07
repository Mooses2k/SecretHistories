# One reverb area per generated room (issue #179). The room's box footprint
# becomes an Area3D; when the player's body enters, the area re-parameterizes
# the one shared "Reverb" audio bus from the room size. Placement mirrors the
# room fog volumes: ONE SpawnData per room, anchored on the free cell nearest
# the room center, position and size travel as custom properties, and the
# step draws NO RNG so the generation seed stream is untouched. EMPTY-type
# rooms are corridor cells: they get no area, so they resolve to the small
# default reverb through the bus's defaults.
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

# Grown horizontally into the surrounding 0.15 m walls, mirroring the room
# fog volumes' buried-margin approach, so the area does not end exactly on
# the wall face and shared-wall boxes only overlap inside wall geometry.
const HORIZONTAL_WALL_MARGIN : float = 0.15
# Grown vertically into the floor slab and above the ceiling line, so the
# player's body center of mass stays inside the box everywhere in the room.
const VERTICAL_SLAB_MARGIN : float = 0.2

const REVERB_AREA_SCENE_PATH : String = "res://scenes/effects/room_reverb_area.tscn"

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------

### Built-in Virtual Overrides --------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------

### Private Methods -------------------------------------------------------------------------------

func _execute_step(data : WorldData, _gen_data : Dictionary, _generation_seed : int) -> void:
	for room_value in data.get_all_rooms():
		var room := room_value as RoomData
		if room.type == RoomData.OriginalPurpose.EMPTY:
			continue
		_spawn_room_reverb(data, room)


func _spawn_room_reverb(data : WorldData, room : RoomData) -> void:
	var anchor_cell := _pick_anchor_cell(data, room)
	if anchor_cell < 0:
		return

	var spawn_data := SpawnData.new()
	spawn_data.scene_path = REVERB_AREA_SCENE_PATH
	spawn_data.amount = 1
	spawn_data.set_center_position_in_cell(CellFilter.get_cell_position(data, anchor_cell))
	spawn_data.set_custom_property("position", _room_box_center(room))
	spawn_data.set_custom_property("size", _room_box_size(room))
	data.set_object_spawn_data_to_cell(anchor_cell, spawn_data)


## Room interior bounds grown into the surrounding walls, floor slab and
## ceiling line, identical geometry to the fog volumes' boxes.
func _room_box_size(room : RoomData) -> Vector3:
	return Vector3(
		room.rect2.size.x * WorldData.CELL_SIZE + HORIZONTAL_WALL_MARGIN * 2.0,
		WorldData.WALL_SIZE + VERTICAL_SLAB_MARGIN * 2.0,
		room.rect2.size.y * WorldData.CELL_SIZE + HORIZONTAL_WALL_MARGIN * 2.0
	)


func _room_box_center(room : RoomData) -> Vector3:
	return Vector3(
		room.rect2.position.x * WorldData.CELL_SIZE + room.rect2.size.x * WorldData.CELL_SIZE * 0.5,
		WorldData.WALL_SIZE * 0.5,
		room.rect2.position.y * WorldData.CELL_SIZE + room.rect2.size.y * WorldData.CELL_SIZE * 0.5
	)


## Free cell nearest the room center, so the anchor never displaces item
## spawns other steps placed mid-room. Deterministic: draws no RNG.
func _pick_anchor_cell(data : WorldData, room : RoomData) -> int:
	var free_cells := CellFilter.filter_available_cells(data, room.cell_indexes)
	if free_cells.is_empty():
		return -1

	var center := _room_box_center(room)
	var best_cell : int = free_cells[0]
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
