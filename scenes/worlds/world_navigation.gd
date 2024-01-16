extends Spatial


export var margin : float = 0.3
export var wall_thickness : float = 0.15
export var preview : bool = false
export var preview_material : Material
#export var doors_enabled : bool = true setget set_doors_enabled
var data : WorldData
var walls_done = Dictionary()

#var door_scene = preload("res://scenes/objects/world_objects/doors/door.tscn")
#stores the navmeshes for each door, similar to wall_meta on the WorldData resource
var doors := Dictionary()

var navigation_blocking_objects : Array = [
	"res://scenes/objects/large_objects/lighting/floor_candelabra.tscn",
]

var sarcophagus : Array = [
	"res://scenes/objects/large_objects/sarcophagi/sarcophagus.tscn",
	"res://scenes/objects/large_objects/sarcophagi/sarcophagus_base.tscn",
]

var point_viewer = MultiMeshInstance.new()
#func set_doors_enabled(value : bool):
#	doors_enabled = value
#	var xform = Transform.IDENTITY
#	if not doors_enabled:
#		xform = Transform(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.UP*1000.0)
#	for idx in doors_x.keys():
#		navmesh_set_transform(doors_x[idx], xform)
#	for idx in doors_z.keys():
#		navmesh_set_transform(doors_z[idx], xform)


func is_cell_walkable(cell_index : int) -> bool:
	var result = data.get_cell_type(cell_index) != data.CellType.EMPTY;
	if result:
		var room_data = data.get_cell_meta(cell_index, WorldData.CellMetaKeys.META_ROOM_DATA)
		if room_data is RoomData:
			result = result and room_data.type != RoomData.OriginalPurpose.UP_STAIRCASE
			result = result and room_data.type != RoomData.OriginalPurpose.DOWN_STAIRCASE
	if result:
		var spawn_data = data.get_objects_to_spawn().get(cell_index)
		# FIXME : This is a hack to determine which cells the sarcophagus will actually block
		if spawn_data is SpawnData:
			result = result and not navigation_blocking_objects.has(spawn_data.scene_path) and spawn_data.amount > 0
			if result and sarcophagus.has(spawn_data.scene_path):
				var sarcophagus_wall = spawn_data._custom_properties[0]["wall_direction"]
				if sarcophagus_wall >= 0:
					var neighbour = data.get_neighbour_cell(cell_index, sarcophagus_wall)
					result = result and spawn_data == data.get_objects_to_spawn().get(neighbour)
				else:
					result = false
	return result


func set_door_navmesh_enabled(cell_index : int, direction : int, value : bool):
	pass


func is_door_navmesh_enabled(cell_index : int, direction : int) -> bool:
	var navmesh = doors.get(data._get_wall_index(cell_index, direction)) as NavigationMeshInstance
	if navmesh:
		return (navmesh as NavigationMeshInstance).enabled
	return false


func get_door_navmesh_instance(cell_index : int, direction : int) -> NavigationMeshInstance:
	return doors.get(data._get_wall_index(cell_index, direction))


func set_door_navmesh_instance(cell_index : int, direction : int, value = null):
	var idx = data._get_wall_index(cell_index, direction)
	if value == null:
		doors.erase(idx)
	else:
		doors[idx] = value


func update_navigation():
	var cell_size = 0.1
	
	NavigationServer.map_set_cell_size(get_world().navigation_map, cell_size)
	var cell_height = NavigationServer.map_get_cell_height(get_world().navigation_map)
	
	var all_points = Array()
	# This array stores, for each cell, the room index of the room that cell belongs to
	# A room is defined, in this script, as a connected walkable area (without going through any doors)
	# and may not match the room definitions in the map data itself
	var rooms = PoolIntArray()
	rooms.resize(data.cell_count)
	# A room index of 0 means the cell doesn't belong to any room yet
	rooms.fill(0)
	
	var current_room = 0
	
	var navpoly = NavigationPolygon.new()
	for i in data.cell_count:
		# Found the first walkable cell in a given room
		if is_cell_walkable(i) and rooms[i] == 0:
			# We found a new room, assign an index to it
			current_room += 1
			# If this is the first walkable cell in the room, it must be touching the contouring
			# polygon of that room, so we find the polygon here
			var contour = get_contour_polygon(i, WorldData.Direction.NORTH)
			# Now, we need to find any enclosed areas inside the room, or 'holes' in the polygon
			var holes = Array()
			
			var queue = Dictionary()
			# Immediately adds current cell to the queue
			queue[i] = true
			while not queue.empty():
				var current = queue.keys()[0]
				rooms[current] = current_room
				for dir in WorldData.Direction.DIRECTION_MAX:
					var cell = data.get_neighbour_cell(current, dir)
					var wall_type = data.get_wall_type(current, dir)
					# If the next cell is not empty, treat the edge as a wall
					if not is_cell_walkable(cell):
						wall_type = WorldData.EdgeType.WALL
					if  (not queue.has(cell) ) and rooms[cell] == 0 and wall_type == data.EdgeType.EMPTY:
						queue[cell] = true
					if wall_type != WorldData.EdgeType.EMPTY and (not walls_done.has(current) or not walls_done[current].has(dir)):
						holes.push_back(get_contour_polygon(current, dir))
					if wall_type == WorldData.EdgeType.DOOR or wall_type == WorldData.EdgeType.HALFDOOR_N or wall_type == WorldData.EdgeType.HALFDOOR_P:
						if get_door_navmesh_instance(current, dir) == null:
							var verts = gen_door_navmesh(current, dir)
							var verts_3d = PoolVector3Array()
							verts_3d.resize(verts.size())
							var pos = Vector3.ZERO
							for v in verts.size():
								var vert = verts[v]
								verts_3d[v] = Vector3(vert.x, cell_height, vert.y)
								pos += verts_3d[v]
							pos /= 4.0
							pos.y = 0.0
							var navmesh = NavigationMesh.new()
							navmesh.cell_size = cell_size
							navmesh.cell_height = cell_height
							navmesh.vertices = verts_3d
							all_points.append_array(Array(verts_3d))
							navmesh.polygons = [PoolIntArray([0, 1, 2, 3])]
							var navmesh_instance = AutoCleanNavigationMeshInstance.new()
							navmesh_instance.navmesh = navmesh
							
							call_deferred("add_child", navmesh_instance)
#							var navmesh_index = navmesh_add(navmesh, Transform.IDENTITY)
							set_door_navmesh_instance(current, dir, navmesh_instance)
				var pillar = gen_pillar_navmesh(current)
				if pillar:
					holes.push_back(pillar)
				queue.erase(current)
			
			navpoly.clear_outlines()
			navpoly.add_outline(contour)
#			print("holes :")
			for hole in holes:
#				print(var2str(hole))
				navpoly.add_outline(hole)
			navpoly.make_polygons_from_outlines()
			
			var vertices_3d = PoolVector3Array()
			var vertices_2d = navpoly.vertices
			vertices_3d.resize(vertices_2d.size())
			for v in vertices_2d.size():
				var vertex_2d = vertices_2d[v]
				vertices_3d[v] = Vector3(vertex_2d.x, cell_height, vertex_2d.y)
			
			var navmesh = NavigationMesh.new()
			navmesh.cell_size = cell_size
			navmesh.cell_height = cell_height
			navmesh.vertices = vertices_3d
			all_points.append_array(Array(vertices_3d))
			navmesh.polygons = navpoly.polygons
			var nav_instance = AutoCleanNavigationMeshInstance.new()
			nav_instance.navmesh = navmesh
			call_deferred("add_child", nav_instance)
#			navmesh_add(navmesh, Transform.IDENTITY)
	walls_done.clear()
	var multimesh = MultiMesh.new()
	multimesh.mesh = CubeMesh.new()
	(multimesh.mesh as CubeMesh).size = 0.1 * Vector3.ONE
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.color_format = MultiMesh.COLOR_8BIT
	multimesh.instance_count = all_points.size()
	multimesh.visible_instance_count = multimesh.instance_count
	for i in all_points.size():
		var p = all_points[i]
		p.y = randf() + 0.5
		multimesh.set_instance_transform(i, Transform.IDENTITY.translated(p))
		multimesh.set_instance_color(i, Color.from_hsv(randf(), 0.8, 1.0))
	point_viewer.multimesh = multimesh
	point_viewer.material_override = preview_material
	point_viewer.visible = preview
	if not point_viewer.is_inside_tree():
		add_child(point_viewer)


func gen_pillar_navmesh(cell: int):
	var pos = data.get_int_position_from_cell_index(cell)
	var x = pos[0]
	var z = pos[1]
	var pillar = data.get_cell_index_from_int_position(x, z)
	var radius = data.pillar_radius.get(pillar)
	if radius == null:
		return null
	if is_cell_walkable(cell):
		# Other 3 cells around pillar
		var n = data.get_neighbour_cell(cell, WorldData.Direction.NORTH)
		var nw = data.get_neighbour_cell(n, WorldData.Direction.WEST)
		var w = data.get_neighbour_cell(cell, WorldData.Direction.WEST)
		
		var are_cells_walkable = is_cell_walkable(n) and is_cell_walkable(nw) and is_cell_walkable(w);
		
		# Walls around the potential pillar
		var n_wall = data.get_wall_type(nw, WorldData.Direction.EAST)
		var s_wall = data.get_wall_type(cell, WorldData.Direction.WEST)
		var e_wall = data.get_wall_type(cell, WorldData.Direction.NORTH)
		var w_wall = data.get_wall_type(nw, WorldData.Direction.SOUTH)
		
		var empty = data.EdgeType.EMPTY
		var are_walls_free = n_wall == empty and s_wall == empty and e_wall == empty and w_wall == empty
		
		var result = PoolVector2Array()
		if are_cells_walkable and are_walls_free:
			var origin = data.get_local_cell_position(cell)
			var origin_2d = Vector2(origin.x, origin.z)
			var vec = Vector2.RIGHT * (radius + margin)
			for i in 8:
				result.push_back(origin_2d + vec)
				vec = vec.rotated(2.0 * PI / 8.0)
			return result
	return null


func gen_door_navmesh(cell : int, direction : int) -> PoolVector2Array:
	var vec_direction = PoolVector2Array()
	vec_direction.resize(WorldData.Direction.DIRECTION_MAX)
	vec_direction[WorldData.Direction.NORTH] = Vector2(0.0, -1.0)
	vec_direction[WorldData.Direction.SOUTH] = Vector2(0.0,  1.0)
	vec_direction[WorldData.Direction.EAST] = Vector2( 1.0, 0.0)
	vec_direction[WorldData.Direction.WEST] = Vector2(-1.0, 0.0)
	var half_cell = data.CELL_SIZE * 0.5
	var local_margin = margin / half_cell
	var local_thickness = wall_thickness / half_cell
	var result = Array()
	var new_points = Array()
	var wall_type = data.get_wall_type(cell, direction)
	match wall_type:
		WorldData.EdgeType.HALFDOOR_N:
			var gap = 0.5 * data.get_wall_meta(cell, direction) / half_cell - local_margin - local_thickness
			gap = max(gap, 0.05)
			if direction == WorldData.Direction.EAST or direction == WorldData.Direction.NORTH:
				# ┌   * ┐ * - X -1
				#     *   *
				#         
				# └     ┘       +1
				# |
				# Z
				#-1    +1
				# forms a rectangle, taking the door shape int account
				new_points = [
					Vector2(1.0 + local_margin + local_thickness, -1.0 + gap),
					Vector2(1.0 + local_margin + local_thickness, -1.0),
					Vector2(1.0 - local_margin - local_thickness, -1.0),
					Vector2(1.0 - local_margin - local_thickness, -1.0 + gap),
				]
			else:
				# ┌     ┐ - X -1
				#      
				#     *   * 
				# └   * ┘ *   +1
				# |
				# Z
				#-1    +1
				#forms a rectangle, taking the door shape into account
				new_points = [
					Vector2(1.0 + local_margin + local_thickness, 1.0),
					Vector2(1.0 + local_margin + local_thickness, 1.0 - gap),
					Vector2(1.0 - local_margin - local_thickness, 1.0 - gap),
					Vector2(1.0 - local_margin - local_thickness, 1.0)
				]
		WorldData.EdgeType.HALFDOOR_P:
			var gap = 0.5 * data.get_wall_meta(cell, direction) / half_cell - local_margin - local_thickness
			gap = max(gap, 0.05)
			if direction == WorldData.Direction.WEST or direction == WorldData.Direction.SOUTH:
				# ┌   * ┐ - X -1
				#     *  
				#     |    
				# └   | ┘     +1
				# |
				# Z
				#-1    +1
				# forms a straight line, adding a point at *, taking the door(:) width into account
				new_points = [
					Vector2(1.0 + local_margin + local_thickness, -1.0 + gap),
					Vector2(1.0 + local_margin + local_thickness, -1.0),
					Vector2(1.0 - local_margin - local_thickness, -1.0),
					Vector2(1.0 - local_margin - local_thickness, -1.0 + gap),
				]
			else:
				# ┌   * ┐ - X -1
				#     |  
				#     *    
				# └   : ┘     +1
				# |
				# Z
				#-1    +1
				#forms a straight line, adding a point at *, taking the door(:) width into account
				new_points = [
					Vector2(1.0 + local_margin + local_thickness, 1.0),
					Vector2(1.0 + local_margin + local_thickness, 1.0 - gap),
					Vector2(1.0 - local_margin - local_thickness, 1.0 - gap),
					Vector2(1.0 - local_margin - local_thickness, 1.0)
				]
		WorldData.EdgeType.DOOR:
			# ┌   | ┐ - X -1
			#     °  °
			#     °  ° 
			# └   | ┘     +1
			# |
			# Z
			#-1    +1
			#forms a straight line, adding a point at *, taking the door(°) edges into account
			var half_gap = 0.5 * data.get_wall_meta(cell, direction) / half_cell - local_margin - local_thickness
			half_gap = max(half_gap, 0.05)
			new_points = [
				Vector2(1.0 + local_margin + local_thickness, half_gap),
				Vector2(1.0 + local_margin + local_thickness, -half_gap),
				Vector2(1.0 - local_margin - local_thickness, -half_gap),
				Vector2(1.0 - local_margin - local_thickness, half_gap),
			]
	var cell_x = vec_direction[direction]
	var cell_y = vec_direction[data.direction_rotate_cw(direction)]
	var cell_pos = data.get_local_cell_position(cell)
	var offset = Vector2.ONE * half_cell + Vector2(cell_pos.x, cell_pos.z)
	for p in new_points:
		result.push_back((p.x * cell_x + p.y * cell_y) * half_cell + offset)
	return PoolVector2Array(result)


func get_contour_polygon(start_cell : int, start_direction : int) -> PoolVector2Array:
	
	var vec_direction = PoolVector2Array()
	vec_direction.resize(WorldData.Direction.DIRECTION_MAX)
	vec_direction[WorldData.Direction.NORTH] = Vector2(0.0, -1.0)
	vec_direction[WorldData.Direction.SOUTH] = Vector2(0.0,  1.0)
	vec_direction[WorldData.Direction.EAST] = Vector2( 1.0, 0.0)
	vec_direction[WorldData.Direction.WEST] = Vector2(-1.0, 0.0)
	
	var half_cell = data.CELL_SIZE * 0.5
	# Margin distance normalized to half_cell dimensions
	var local_margin = margin / half_cell
	var local_thickness = wall_thickness / half_cell
	var result = Array()
	
	var current_cell = start_cell
	var current_direction = start_direction
	while not (current_cell == start_cell and current_direction == start_direction) or result.size() == 0:
		if current_cell == -1:
			break
		if not walls_done.has(current_cell):
			walls_done[current_cell] = Array()
		(walls_done[current_cell] as Array).push_back(current_direction)
		# This algorithm follows the wall, keeping it to the right
		var follow_direction = data.direction_rotate_ccw(current_direction)
		var follow_cell = data.get_neighbour_cell(current_cell, follow_direction)
		var follow_wall_type = data.get_wall_type(current_cell, follow_direction)
		var is_internal_corner = follow_wall_type != WorldData.EdgeType.EMPTY or not is_cell_walkable(follow_cell)
		
		var current_wall_type = data.get_wall_type(current_cell, current_direction)
		# If the next cell is not walkable, treat it as a wall
		if not is_cell_walkable(data.get_neighbour_cell(current_cell, current_direction)):
			current_wall_type = data.EdgeType.WALL
		var new_points = Array()
		
		var cell_x = vec_direction[current_direction]
		var cell_y = vec_direction[WorldData.ROTATE_RIGHT[current_direction]]
		
		match current_wall_type:
			data.EdgeType.EMPTY:	
				# ┌     ┐ - X -1
				#        
				#     *- *  
				# └   | ┘     +1
				# |
				# Z
				#-1    +1
				#forms an external corner
				is_internal_corner = false
				new_points = [
					Vector2(1.0 - local_margin - local_thickness, 1.0 - local_margin - local_thickness),
#					Vector2(1.0, 1.0 - local_margin - local_thickness),
					]
				follow_direction = current_direction
			data.EdgeType.WALL:
				# ┌   * ┐ - X -1
				#     |  
				#     |    
				# └   | ┘     +1
				# |
				# Z
				#-1    +1
				# Since this forms a straight line, it's only necessary to add a point at the next turn/endpoint
#				new_points = [Vector2(1.0 - local_margin - local_thickness, -1.0 + end_margin + local_thickness)]
				pass
			data.EdgeType.HALFDOOR_N:
				var gap = 0.5 * data.get_wall_meta(current_cell, current_direction) / half_cell - local_margin - local_thickness
				gap = max(gap, 0.05)
				# HALFDOOR_N means that the open side of the door is on the lower coordinate direction (i.e, if a
				# door is along the X axis, the opening will be on the West side of the edge)
				if follow_direction == WorldData.Direction.NORTH or follow_direction == WorldData.Direction.WEST:
					# ┌   * ┐ - X -1
					#     *  
					#     |    
					# └   | ┘     +1
					# |
					# Z
					#-1    +1
					# forms a straight line, adding a point at *, taking the door(:) width into account
					new_points = [
						Vector2(1.0 - local_margin - local_thickness, -1.0 + gap),
						Vector2(1.0 - local_margin - local_thickness, -1.0)
					]
				else:
					# ┌   * ┐ - X -1
					#     |  
					#     *    
					# └   : ┘     +1
					# |
					# Z
					#-1    +1
					#forms a straight line, adding a point at *, taking the door(:) width into account
					new_points = [
						Vector2(1.0 - local_margin - local_thickness, 1.0 - gap),
#						Vector2(1.0 - local_margin - local_thickness, -1.0 + end_margin + local_thickness)
					]
			data.EdgeType.HALFDOOR_P:
				var gap = 0.5 * data.get_wall_meta(current_cell, current_direction) / half_cell - local_margin - local_thickness
				gap = max(gap, 0.05)
				if follow_direction == WorldData.Direction.SOUTH or follow_direction == WorldData.Direction.EAST:
					# ┌   * ┐ - X -1
					#     *  
					#     |    
					# └   | ┘     +1
					# |
					# Z
					#-1    +1
					# forms a straight line, adding a point at *, taking the door(:) width into account
					new_points = [
						Vector2(1.0 - local_margin - local_thickness, -1.0 + gap), 
						Vector2(1.0 - local_margin - local_thickness, -1.0),
					]
				else:
					# ┌   * ┐ - X -1
					#     |  
					#     *    
					# └   : ┘     +1
					# |
					# Z
					#-1    +1
					#forms a straight line, adding a point at *, taking the door(:) width into account
					new_points = [
						Vector2(1.0 - local_margin - local_thickness, 1.0 - gap),
#						Vector2(1.0 - local_margin - local_thickness, -1.0 + end_margin + local_thickness)
					]
			data.EdgeType.DOOR:
				# ┌   * ┐ - X -1
				#     ° 
				#     °    
				# └   | ┘     +1
				# |
				# Z
				#-1    +1
				#forms a straight line, adding a point at *, taking the door(°) edges into account
				var half_gap = 0.5 * data.get_wall_meta(current_cell, current_direction) / half_cell - local_margin - local_thickness
				half_gap = max(half_gap, 0.05)
				new_points = [
					Vector2(1.0 - local_margin - local_thickness, half_gap),
					Vector2(1.0 - local_margin - local_thickness, -half_gap),
#					Vector2(1.0 - local_margin - local_thickness, -1.0 + end_margin + local_thickness)
				]
		if is_internal_corner:
			new_points.push_back(Vector2(1.0 - local_margin - local_thickness, -1.0 + local_margin + local_thickness))
		var cell_pos = data.get_local_cell_position(current_cell)
		var offset = Vector2.ONE * half_cell + Vector2(cell_pos.x, cell_pos.z)
		for p in new_points:
			result.push_back((p.x * cell_x + p.y * cell_y) * half_cell + offset)
		follow_wall_type = data.get_wall_type(current_cell, follow_direction)
		follow_cell = data.get_neighbour_cell(current_cell, follow_direction)
		if follow_wall_type == data.EdgeType.EMPTY and is_cell_walkable(follow_cell):
			current_direction = WorldData.ROTATE_RIGHT[follow_direction]
			current_cell = data.get_neighbour_cell(current_cell, follow_direction)
		else:
			current_direction = follow_direction
	return PoolVector2Array(result)
