extends GenerationStep

export var room_size_min : int = 1
export var room_size_max : int = 4

export var room_count_min : int = 32
export var room_count_max : int = 32

export var room_size_scale : int = 2

export var room_min_distance : int = 1
export var intersection_chance : float = 1
export var min_intersection_size : int = 3

export(Array, WorldData.CellType) var override_cells : Array = [WorldData.CellType.EMPTY]

var actual_room_max : int
var actual_room_min : int


# Randomly generates a set of rooms into data, stores the generated rooms
# as an array of Rect2 into gen_data, under the ket ROOM_ARRAY_KEY
func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	generate_rooms(data, gen_data, generation_seed)
	fill_map_data(data, gen_data)


func generate_rooms(data : WorldData, gen_data : Dictionary, generation_seed : int):
	actual_room_max = int(min(room_size_max, (min(data.get_size_x(), data.get_size_z()) - 2)/room_size_scale))
	actual_room_min = int(min(room_size_min, (min(data.get_size_x(), data.get_size_z()) - 2)/room_size_scale))
	
	var random : RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = generation_seed
	
	var rooms : Array = gen_data[ROOM_ARRAY_KEY] if gen_data.has(ROOM_ARRAY_KEY) else Array()
	var room_try_count : int = random.randi_range(room_count_min, room_count_max)
	for i in room_try_count:
		var room : Rect2 = _gen_room_rect(data, random)
		var intersection_test = room.grow(room_min_distance)
		var intersecting_rooms = Array()
		for _r in rooms:
			var other_room : Rect2 = _r as Rect2
			if intersection_test.intersects(other_room):
				intersecting_rooms.push_back(other_room)
		var should_add_room = intersecting_rooms.empty()
		if random.randf() <= intersection_chance and intersection_chance != 0.0:
			var room_border = room.grow(1)
			for _r in intersecting_rooms:
				var other_room : Rect2 = _r as Rect2
				var intersection = room_border.clip(other_room)
				var big_intersection_size = max(intersection.size.x, intersection.size.y)
				if big_intersection_size - 1 < min_intersection_size:
					should_add_room = false
					break
		if should_add_room and check_room_space(data, room):
			rooms.push_back(room)
	gen_data[ROOM_ARRAY_KEY] = rooms


func check_room_space(data : WorldData, room : Rect2) -> bool:
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			var i = data.get_cell_index_from_int_position(x, y)
			if not override_cells.has(data.get_cell_type(i)):
				return false
	return true


func fill_map_data(data : WorldData, gen_data : Dictionary):
	var rooms : Array = gen_data.get(ROOM_ARRAY_KEY) as Array
	
	for index in range(1, rooms.size()):
		var room : Rect2 = rooms[index] as Rect2
		data.fill_room_data(room, data.CellType.ROOM, RoomData.OriginalPurpose.EMPTY)


func _gen_room_rect(data : WorldData, random : RandomNumberGenerator) -> Rect2:
	var value := Rect2()
	
	var s_x = int(random.randi_range(actual_room_min, actual_room_max)*room_size_scale)
	var s_z = int(random.randi_range(actual_room_min, actual_room_max)*room_size_scale)
	
	var p_x = random.randi_range(1, data.get_size_x() - 1 - s_x)
	var p_z = random.randi_range(1, data.get_size_z() - 1 - s_z)
	
	value = Rect2(p_x, p_z, s_x, s_z)
	
	return value
