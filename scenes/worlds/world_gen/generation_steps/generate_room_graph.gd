extends GenerationStep


const CONNECTION_GRAPH_KEY = "connection_graph"
const DELAUNAY_GRAPH_KEY = "delaunay_graph"

export var edges_to_keep_min_ratio : float = 0.1
export var edges_to_keep_max_ratio : float = 0.4
export var edges_to_keep_abs_min : int = 2

const RoomGenerator = preload("generate_rooms.gd")

# Array of indices that represent "entry" or "up" staircases. These can only connect TO other rooms
# but not be connected FROM other rooms, because Mooses2k wants level staircases to only have one
# door.
var _entry_staircases := []

# Array of indices that represent "exit" or "down" staircases. These can only be connected FROM 
# other rooms but connect TO other rooms, because Mooses2k wants level staircases to only have one
# door.
var _exit_staircases := []


# Generates a graph connecting rooms to each other, the graph is generated
# as a Dictionary, where the key K represents the cell of index K, and the value
# Dictionary[k] is an array of all the indices I that K is connected to, such
# that K < I
func _execute_step(data : WorldData, gen_data : Dictionary, generation_seed : int):
	var _rooms = gen_data.get(RoomGenerator.ROOM_ARRAY_KEY)
	if _rooms is Array:
		var random = RandomNumberGenerator.new()
		random.seed = generation_seed
		var rooms : Array = _rooms as Array
		var groups : Array = group_intersecting_rooms(rooms)
		var delaunay : Dictionary = get_delaunay_from_groupings(data, groups, random)
		gen_data[DELAUNAY_GRAPH_KEY] = delaunay.duplicate(true)
		_exclude_unwanted_edges(delaunay, random)
		var graph : Dictionary = get_mst_from_delaunay(data, delaunay)
		add_extra_edges(delaunay, graph, random)
		gen_data[CONNECTION_GRAPH_KEY] = graph
	pass


# gets all rooms as an Array of Rect2, returns an Array of Arrays of Rect2,
# where each internal Array of Rect2 contains all rooms that mutually intersect
# each other
func group_intersecting_rooms(rooms : Array) -> Array:
	var groups : Array = Array()
	
	# First intersection pass
	for i in rooms.size():
		var room : Rect2 = rooms[i] as Rect2
		var group_found : bool = false
		for g in groups:
			for j in g:
				var other_room = rooms[j] as Rect2
				if rooms_intersect(room, other_room):
					g.push_back(i)
					group_found = true
					break
			if group_found:
				break
		if not group_found:
			groups.push_back([i])
	# Refine groups (if A intersects B and B intersects C, A intersects C)
	var can_refine : bool = true
	while can_refine:
		can_refine = false
		var merged = Array()
		for g in groups.size():
			var can_merge : bool = false
			var group : Array = groups[g]
			for m in merged.size():
				var group_merged : Array = merged[m]
				for i in group:
					for j in group_merged:
						if rooms_intersect(rooms[i], rooms[j]):
							can_merge = true
							break
					if can_merge:
						break
				if can_merge:
					group_merged.append_array(group)
					can_refine = true
					break
			if not can_merge:
				merged.push_back(group.duplicate())
		groups = merged.duplicate()
	# convert indices into rooms
	for g in groups.size():
		for r in groups[g].size():
			groups[g][r] = rooms[groups[g][r]]
	return groups


func rooms_intersect(a : Rect2, b : Rect2) -> bool:
	var a_border : Rect2 = a.grow(1)
	var clip : Rect2 = a_border.clip(b)
	return clip.size.x > 1 or clip.size.y > 1


func get_delaunay_from_groupings(data : WorldData, groups : Array, random : RandomNumberGenerator) -> Dictionary:
	var edges : Dictionary = Dictionary()
	var room_centers = PoolVector2Array()
	room_centers.resize(groups.size())
	var cells = PoolIntArray()
	cells.resize(groups.size())
	for i in groups.size():
		var r = random.randi_range(0, groups[i].size() - 1)
		var room = groups[i][r] as Rect2
		var center = room.position + 0.5*room.size
		var x = int(center.x)
		var y = int(center.y)	
		
		var cell_index := data.get_cell_index_from_int_position(x, y)
		var room_data := data.get_cell_meta(cell_index, data.CellMetaKeys.META_ROOM_DATA) as RoomData
		if room_data.type == room_data.OriginalPurpose.UP_STAIRCASE:
			_entry_staircases.append(cell_index)
		elif room_data.type == room_data.OriginalPurpose.DOWN_STAIRCASE:
			_exit_staircases.append(cell_index)
		
		cells[i] = cell_index
		room_centers[i] = center
	var delaunay : PoolIntArray = Geometry.triangulate_delaunay_2d(room_centers)
	for i in delaunay.size()/3:
		graph_add_edge(edges, cells[delaunay[3*i + 0]], cells[delaunay[3*i + 1]])
		graph_add_edge(edges, cells[delaunay[3*i + 1]], cells[delaunay[3*i + 2]])
		graph_add_edge(edges, cells[delaunay[3*i + 2]], cells[delaunay[3*i + 0]])
	return edges


func get_mst_from_delaunay(data : WorldData, delaunay : Dictionary) -> Dictionary:
	var edges : Dictionary = Dictionary()
	var added_verts : Dictionary = Dictionary()
	added_verts[delaunay.keys()[0]] = true
	var vert_added : bool = true
	while vert_added:
		vert_added = false
		var candidate_a = -1
		var candidate_b = -1
		var candidate_dist = INF
		for a in added_verts.keys():
			var p_a = data.get_local_cell_position(a)
			for b in graph_get_edges(delaunay, a):
				if not added_verts.has(b):
					var dist = p_a.distance_squared_to(data.get_local_cell_position(b))
					if dist < candidate_dist:
						candidate_a = a
						candidate_b = b
						candidate_dist = dist
		if candidate_a > 0:
			graph_add_edge(edges, candidate_a, candidate_b)
			graph_remove_edge(delaunay, candidate_a, candidate_b)
			added_verts[candidate_b] = true
			vert_added = true
	return edges


func add_extra_edges(from : Dictionary, to : Dictionary, random : RandomNumberGenerator):
	var edge_count = graph_edge_count(from)
	var ratio = random.randf_range(edges_to_keep_min_ratio, edges_to_keep_max_ratio)
	var extra_count = int(ratio*edge_count)
	extra_count = max(extra_count, min(edges_to_keep_abs_min, edge_count))
	for i in extra_count:
		var a_count = from.keys().size()
		var a = from.keys()[random.randi_range(0, a_count - 1)]
		var b_count = from[a].size()
		var b = from[a][random.randi_range(0, b_count - 1)]
		graph_add_edge(to, a, b)
		graph_remove_edge(from, a, b)
	pass


func graph_add_edge(graph : Dictionary, from : int, to : int):
	if from != to:
		var a = min(from, to)
		var b = max(from, to)
		if not graph.has(a):
			graph[a] = []
		if not graph[a].has(b):
			graph[a].push_back(b)


func graph_remove_edge(graph : Dictionary, from : int, to : int):
	if from != to:
		var a = min(from, to)
		var b = max(from, to)
		if graph.has(a):
			graph[a].erase(b)
			if (graph[a] as Array).empty():
				graph.erase(a)


func graph_has_edge(graph : Dictionary, from : int, to : int) -> bool:
	if from != to:
		var a = min(from, to)
		var b = max(from, to)
		if graph.has(a):
			return graph[a].has(b)
	return false


func graph_edge_count(graph : Dictionary) -> int:
	var result = 0
	# each edge is counted exactly once, since they are always stored
	# with the key as the lower index
	for e in graph.values():
		result += e.size()
	return result


func graph_get_edges(graph : Dictionary, from : int) -> Array:
	var result = Array()
	for i in from:
		if graph.has(i) and graph[i].has(from):
			result.push_back(i)
	result.append_array(graph.get(from, []))
	return result


func _exclude_unwanted_edges(delaunay: Dictionary, random: RandomNumberGenerator) -> void:
	_exclude_incoming_connections_from_entry_staircases(delaunay, random)
	_exclude_outgoing_connections_from_exit_staircases(delaunay, random)
	for cell_index in delaunay.keys().duplicate():
		if delaunay[cell_index].empty():
			delaunay.erase(cell_index)


# Excludes all incoming connetions to enter staircaises, and if entry staircases have more than
# one outgoing connections, exclude them randomly until there is only one.
func _exclude_incoming_connections_from_entry_staircases(
		delaunay: Dictionary, random: RandomNumberGenerator
) -> void:
	var exclude_possibilities := []
	for staircase_index in _entry_staircases:
		for cell_index in delaunay:
			var edges := delaunay[cell_index] as Array
			if cell_index != staircase_index:
				var index_to_exclude := edges.find(staircase_index)
				if index_to_exclude != -1:
					var exclude_data := {
						cell_index = cell_index,
						edge_index = index_to_exclude
					}
					exclude_possibilities.append(exclude_data)
			else:
				if edges.size() > 1:
					var original_size := edges.size()
					for _i in original_size - 1:
						var random_index := random.randi() % edges.size()
						edges.remove(random_index)
	
	if exclude_possibilities.size() > 1:
		_exclude_connection_randomly_until(1, exclude_possibilities, delaunay, random)


# Excludes all outgoing connection from exit staircases, and makes a list of incoming connections,
# if there are more than one incoming connection, randomly delete them until there is only one.
func _exclude_outgoing_connections_from_exit_staircases(
		delaunay: Dictionary, random: RandomNumberGenerator
) -> void:
	var exclude_possibilities := []
	for staircase_index in _exit_staircases:
		var keys := delaunay.keys()
		for cell_index in keys:
			var edges := delaunay[cell_index] as Array
			if cell_index != staircase_index:
				var index_to_exclude := edges.find(staircase_index)
				if index_to_exclude != -1:
					var exclude_data := {
						cell_index = cell_index,
						edge_index = index_to_exclude
					}
					exclude_possibilities.append(exclude_data)
			else:
				if edges.size() > 0:
					delaunay.erase(cell_index)
	
	if exclude_possibilities.size() > 1:
		_exclude_connection_randomly_until(1, exclude_possibilities, delaunay, random)


func _exclude_connection_randomly_until(
		size_left: int, to_exclude: Array, delaunay: Dictionary,  random: RandomNumberGenerator
) -> void:
	var iterations_to_exclude := to_exclude.size() - size_left
	for _i in iterations_to_exclude:
		var random_index := random.randi() % to_exclude.size()
		var exclude_data := to_exclude[random_index] as Dictionary
		delaunay[exclude_data.cell_index].remove(exclude_data.edge_index)
		to_exclude.remove(random_index)
