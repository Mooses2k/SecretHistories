extends GenerationStep


@export var room_size_min : int = 1
@export var room_size_max : int = 4

@export var room_count_min : int = 32
@export var room_count_max : int = 32

@export var room_size_scale : int = 2

@export var room_min_distance : int = 1
@export var intersection_chance : float = 1
@export var min_intersection_size : int = 3

@export var override_cells : Array = [WorldData.CellType.EMPTY] # (Array, WorldData.CellType)

# Sibling step that owns the RoomPurpose resources (GenerateRoomPurposes in
# procedural_world.tscn). Read only for the Force Room Purpose debug setting,
# to derive the size band the forced purpose accepts.
@export var purpose_step_path : NodePath = NodePath()

var _initial_rooms_size := 0

var actual_room_max : int
var actual_room_min : int

# Roll-unit size bands ([min, max] per axis) the forced purpose accepts, or
# x = -1 when no force is active. Resolved once per execution.
var _forced_roll_x := Vector2i(-1, -1)
var _forced_roll_z := Vector2i(-1, -1)


# Randomly generates a set of rooms into data, stores the generated rooms
# as an array of Rect2 into gen_data, under the ket ROOM_ARRAY_KEY
func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	if gen_data.has(ROOM_ARRAY_KEY):
		_initial_rooms_size = gen_data[ROOM_ARRAY_KEY].size()
	_update_actual_room_bounds(data)
	_resolve_forced_size_band()
	generate_rooms(data, gen_data, generation_seed)
	fill_map_data(data, gen_data)


func generate_rooms(data : WorldData, gen_data : Dictionary, generation_seed : int):
	_update_actual_room_bounds(data)

	var random : RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = generation_seed
	
	var rooms : Array = gen_data[ROOM_ARRAY_KEY] if gen_data.has(ROOM_ARRAY_KEY) else Array()
	var room_try_count : int = random.randi_range(room_count_min, room_count_max)
	# Debug force-fit: attempts roll inside the forced purpose's size band
	# until one room lands in it, so the floor gets at least one EMPTY room
	# the forced purpose can occupy. Every attempt consumes the same number of
	# rng draws regardless of the band, so the stream accounting is unchanged.
	var forced_room_landed := false
	for i in room_try_count:
		var use_forced_band := not forced_room_landed and _forced_roll_x.x >= 0
		var room : Rect2 = _gen_room_rect(
				data, random,
				_forced_roll_x if use_forced_band else Vector2i(-1, -1),
				_forced_roll_z if use_forced_band else Vector2i(-1, -1))
		var intersection_test = room.grow(room_min_distance)
		var intersecting_rooms = Array()
		for _r in rooms:
			var other_room : Rect2 = _r as Rect2
			if intersection_test.intersects(other_room):
				intersecting_rooms.push_back(other_room)
		var should_add_room = intersecting_rooms.is_empty()
		if random.randf() <= intersection_chance and intersection_chance != 0.0:
			var room_border = room.grow(1)
			for _r in intersecting_rooms:
				var other_room : Rect2 = _r as Rect2
				var intersection = room_border.intersection(other_room)
				var big_intersection_size = max(intersection.size.x, intersection.size.y)
				if big_intersection_size - 1 < min_intersection_size:
					should_add_room = false
					break
		if should_add_room and check_room_space(data, room):
			rooms.push_back(room)
			if use_forced_band:
				forced_room_landed = true
	gen_data[ROOM_ARRAY_KEY] = rooms


# Sizes this generator can roll on this map, in roll units (a roll is
# multiplied by room_size_scale at roll time).
func _update_actual_room_bounds(data : WorldData) -> void:
	actual_room_max = int(min(room_size_max, (min(data.get_size_x(), data.get_size_z()) - 2)/room_size_scale))
	actual_room_min = int(min(room_size_min, (min(data.get_size_x(), data.get_size_z()) - 2)/room_size_scale))


func check_room_space(data : WorldData, room : Rect2) -> bool:
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			var i = data.get_cell_index_from_int_position(x, y)
			if not override_cells.has(data.get_cell_type(i)):
				return false
	return true


func fill_map_data(data : WorldData, gen_data : Dictionary):
	var rooms : Array = gen_data.get(ROOM_ARRAY_KEY) as Array
	
	for index in range(_initial_rooms_size, rooms.size()):
		var room : Rect2 = rooms[index] as Rect2
		data.fill_room_data(room, WorldData.OriginalPurpose.EMPTY)


func _gen_room_rect(data : WorldData, random : RandomNumberGenerator,
		forced_roll_x := Vector2i(-1, -1), forced_roll_z := Vector2i(-1, -1)) -> Rect2:
	var value := Rect2()

	var roll_x := forced_roll_x if forced_roll_x.x >= 0 else Vector2i(actual_room_min, actual_room_max)
	var roll_z := forced_roll_z if forced_roll_z.x >= 0 else Vector2i(actual_room_min, actual_room_max)

	var s_x = int(random.randi_range(roll_x.x, roll_x.y) * room_size_scale)
	var s_z = int(random.randi_range(roll_z.x, roll_z.y) * room_size_scale)

	var p_x = random.randi_range(1, data.get_size_x() - 1 - s_x)
	var p_z = random.randi_range(1, data.get_size_z() - 1 - s_z)

	value = Rect2(p_x, p_z, s_x, s_z)

	return value


# Debug force-fit: turns the forced purpose's accepted size range (read from
# its requirements, never hardcoded) into this generator's roll units, so the
# band only ever produces rooms the step's own room_size_scale can roll. When
# the purpose accepts no achievable size, the guarantee is skipped with a
# warning instead of bending the generator.
func _resolve_forced_size_band() -> void:
	_forced_roll_x = Vector2i(-1, -1)
	_forced_roll_z = Vector2i(-1, -1)

	var forced_name := ForceRoomPurpose.get_forced_purpose_name(GameManager.game)
	if forced_name.is_empty():
		return

	var purpose := _find_forced_purpose(forced_name)
	if purpose == null:
		return

	var min_size := ForceRoomPurpose.get_required_min_size(purpose)
	var max_size := ForceRoomPurpose.get_required_max_size(purpose)
	_forced_roll_x = _size_band_to_rolls(min_size.x, max_size.x)
	_forced_roll_z = _size_band_to_rolls(min_size.y, max_size.y)
	if _forced_roll_x.x < 0 or _forced_roll_z.x < 0:
		_forced_roll_x = Vector2i(-1, -1)
		_forced_roll_z = Vector2i(-1, -1)
		push_warning("Force Room Purpose '%s': none of its accepted sizes is achievable at room_size_scale %s."
				% [forced_name, room_size_scale])


func _find_forced_purpose(forced_name : String) -> RoomPurpose:
	var purpose_step := get_node_or_null(purpose_step_path)
	if purpose_step == null:
		push_warning("Force Room Purpose '%s': purpose_step_path is not wired, size guarantee skipped."
				% [forced_name])
		return null

	var resources = purpose_step.get("purpose_resources")
	if resources is Array:
		for value in resources:
			var purpose := value as RoomPurpose
			if purpose and ForceRoomPurpose.get_purpose_display_name(purpose) == forced_name:
				return purpose
	return null


# Converts one axis of the purpose's accepted size range into roll bounds,
# clamped to what this generator can roll on this map. Returns x = -1 when the
# range holds no achievable size that still meets the purpose minimum.
func _size_band_to_rolls(min_size : int, max_size : int) -> Vector2i:
	if min_size <= 0:
		return Vector2i(actual_room_min, actual_room_max)

	var min_roll := (min_size + room_size_scale - 1) / room_size_scale
	var max_roll := actual_room_max if max_size < 0 else max_size / room_size_scale
	min_roll = max(min_roll, actual_room_min)
	max_roll = min(max_roll, actual_room_max)
	if min_roll > max_roll or min_roll * room_size_scale < min_size:
		return Vector2i(-1, -1)
	return Vector2i(min_roll, max_roll)
