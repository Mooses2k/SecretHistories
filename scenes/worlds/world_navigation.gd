extends Navigation

export var margin : float = 0.3
export var wall_thickness : float = 0.15
export var elevation : float = 0.2
#export var doors_enabled : bool = true setget set_doors_enabled
var data : Resource setget set_data
var walls_done = Dictionary()

var door_scene = preload("res://scenes/objects/world_objects/doors/door.tscn")
#stores the navmeshes for each door, similar to wall_meta on the WorldData resource
var doors_x := Dictionary()
var doors_z := Dictionary()


func set_data(value : WorldData):
	data = value

#func set_doors_enabled(value : bool):
#	doors_enabled = value
#	var xform = Transform.IDENTITY
#	if not doors_enabled:
#		xform = Transform(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.UP*1000.0)
#	for idx in doors_x.keys():
#		navmesh_set_transform(doors_x[idx], xform)
#	for idx in doors_z.keys():
#		navmesh_set_transform(doors_z[idx], xform)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func get_door_navmesh_instance(cell_index : int, direction : int) -> NavigationMeshInstance:
	var idx = 0
	match direction:
		WorldData.Direction.NORTH:
			idx = data.get_north_wall_index(cell_index)
		WorldData.Direction.SOUTH:
			idx = data.get_south_wall_index(cell_index)
		WorldData.Direction.EAST:
			idx = data.get_east_wall_index(cell_index)
		WorldData.Direction.WEST:
			idx = data.get_west_wall_index(cell_index)
	var dict : Dictionary = doors_x
	if direction == WorldData.Direction.NORTH or direction == WorldData.Direction.SOUTH:
		dict = doors_z
	return dict.get(idx)


func set_door_navmesh_instance(cell_index : int, direction : int, value = null):
	var idx = 0
	match direction:
		WorldData.Direction.NORTH:
			idx = data.get_north_wall_index(cell_index)
		WorldData.Direction.SOUTH:
			idx = data.get_south_wall_index(cell_index)
		WorldData.Direction.EAST:
			idx = data.get_east_wall_index(cell_index)
		WorldData.Direction.WEST:
			idx = data.get_west_wall_index(cell_index)
	var dict : Dictionary = doors_x
	if direction == WorldData.Direction.NORTH or direction == WorldData.Direction.SOUTH:
		dict = doors_z
	if value == null:
		if dict.has(idx):
			(dict as Dictionary).erase(idx)
	else:
		dict[idx] = value


func update_navigation():
	var start = OS.get_ticks_msec()
	var _data = data as WorldData
	var rooms = PoolIntArray()
	rooms.resize(_data.cell_count)
	for i in _data.cell_count:
		rooms[i] = 0
	
	var current_room = 0
	
	var navpoly = NavigationPolygon.new()
	for i in _data.cell_count:
		if _data.is_cell_free[i] and rooms[i] == 0:
			var contour = get_contour_polygon(i, WorldData.Direction.NORTH)
#			print("Contour")
#			print(var2str(contour))
			var holes = Array()
			current_room += 1
			var queue = Dictionary()
			queue[i] = true
			while not queue.empty():
				var current = queue.keys()[0]
				rooms[current] = current_room
				for dir in WorldData.Direction.DIRECTION_MAX:
					var cell = _data.get_neighbour_cell(current, dir)
					var wall_type = _data.get_wall_type(current, dir)
					if  (not queue.has(cell)) and rooms[cell] == 0 and wall_type == _data.EdgeType.EMPTY:
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
								verts_3d[v] = Vector3(vert.x, elevation, vert.y)
								pos += verts_3d[v]
							pos/= 4.0
							pos.y = 0.0
							var navmesh = NavigationMesh.new()
							navmesh.vertices = verts_3d
							navmesh.polygons = [PoolIntArray([0, 1, 2, 3])]
							var navmesh_instance = NavigationMeshInstance.new()
							navmesh_instance.navmesh = navmesh
							call_deferred("add_child", navmesh_instance)
#							var navmesh_index = navmesh_add(navmesh, Transform.IDENTITY)
							var door_inst = door_scene.instance()
							door_inst.translation = pos
							door_inst.rotation.y = -PI*0.5*dir;
							door_inst.navmesh = navmesh_instance
							call_deferred("add_child", door_inst)
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
				vertices_3d[v] = Vector3(vertex_2d.x, elevation, vertex_2d.y)
			
			var navmesh = NavigationMesh.new()
			navmesh.vertices = vertices_3d
			navmesh.polygons = navpoly.polygons
			var nav_instance = NavigationMeshInstance.new()
			nav_instance.navmesh = navmesh
			call_deferred("add_child", nav_instance)
#			navmesh_add(navmesh, Transform.IDENTITY)
	walls_done.clear()
	var end = OS.get_ticks_msec()
	print("Navmesh generated in ", end - start, " ms")


func gen_pillar_navmesh(cell: int):
	var _data = data as WorldData
	var pos = _data.get_int_position_from_cell_index(cell)
	var x = pos[0]
	var z = pos[1]
	var pillar = _data.get_pillar_index_from_int_position(x, z)
	var radius = _data.pillar_radius.get(pillar)
	if radius == null:
		return null
	if _data.is_cell_free[cell]:
		#cell to the north_west
		var nw = _data.get_neighbour_cell(_data.get_neighbour_cell(cell, WorldData.Direction.NORTH), WorldData.Direction.WEST)
		#walls around the potential pillar
		var n_wall = _data.get_wall_type(nw, WorldData.Direction.EAST)
		var s_wall = _data.get_wall_type(cell, WorldData.Direction.WEST)
		var e_wall = _data.get_wall_type(cell, WorldData.Direction.NORTH)
		var w_wall = _data.get_wall_type(nw, WorldData.Direction.SOUTH)
		var empty = WorldData.EdgeType.EMPTY
		var result = PoolVector2Array()
		if n_wall == s_wall and s_wall == e_wall and e_wall == w_wall and w_wall == empty:
			var origin = _data.get_cell_position(cell)
			var origin_2d = Vector2(origin.x, origin.z)
			var vec = Vector2.RIGHT*(radius + margin)
			for i in 8:
				result.push_back(origin_2d + vec)
				vec = vec.rotated(2.0*PI/8.0)
			return result
	return null


func gen_door_navmesh(cell : int, direction : int) -> PoolVector2Array:
	var vec_direction = PoolVector2Array()
	vec_direction.resize(WorldData.Direction.DIRECTION_MAX)
	vec_direction[WorldData.Direction.NORTH] = Vector2(0.0, -1.0)
	vec_direction[WorldData.Direction.SOUTH] = Vector2(0.0,  1.0)
	vec_direction[WorldData.Direction.EAST] = Vector2( 1.0, 0.0)
	vec_direction[WorldData.Direction.WEST] = Vector2(-1.0, 0.0)
	var _data = data as WorldData
	var half_cell = _data.CELL_SIZE*0.5
	var local_margin = margin/half_cell
	var local_thickness = wall_thickness/half_cell
	var result = Array()
	var new_points = Array()
	var wall_type = _data.get_wall_type(cell, direction)
	match wall_type:
		WorldData.EdgeType.HALFDOOR_N:
			var gap = _data.get_wall_meta(cell, direction)/half_cell - local_margin
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
				#forms a rectangle, taking the door shape int account
				new_points = [
					Vector2(1.0 + local_margin + local_thickness, 1.0),
					Vector2(1.0 + local_margin + local_thickness, 1.0 - gap),
					Vector2(1.0 - local_margin - local_thickness, 1.0 - gap),
					Vector2(1.0 - local_margin - local_thickness, 1.0)
				]
		WorldData.EdgeType.HALFDOOR_P:
			var gap = _data.get_wall_meta(cell, direction)/half_cell - local_margin
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
			var half_gap = _data.get_wall_meta(cell, direction)*0.5/half_cell - local_margin
			new_points = [
				Vector2(1.0 + local_margin + local_thickness, half_gap),
				Vector2(1.0 + local_margin + local_thickness, -half_gap),
				Vector2(1.0 - local_margin - local_thickness, -half_gap),
				Vector2(1.0 - local_margin - local_thickness, half_gap),
			]
	var cell_x = vec_direction[direction]
	var cell_y = vec_direction[WorldData.ROTATE_RIGHT[direction]]
	var cell_pos = _data.get_cell_position(cell)
	var offset = Vector2.ONE*half_cell + Vector2(cell_pos.x, cell_pos.z)
	for p in new_points:
		result.push_back((p.x* cell_x + p.y*cell_y)*half_cell + offset)
	return PoolVector2Array(result)


func get_contour_polygon(start_cell : int, start_direction : int) -> PoolVector2Array:
	var vec_direction = PoolVector2Array()
	vec_direction.resize(WorldData.Direction.DIRECTION_MAX)
	vec_direction[WorldData.Direction.NORTH] = Vector2(0.0, -1.0)
	vec_direction[WorldData.Direction.SOUTH] = Vector2(0.0,  1.0)
	vec_direction[WorldData.Direction.EAST] = Vector2( 1.0, 0.0)
	vec_direction[WorldData.Direction.WEST] = Vector2(-1.0, 0.0)
	
	var _data = data as WorldData
	var half_cell = _data.CELL_SIZE*0.5
	var local_margin = margin/half_cell
	var local_thickness = wall_thickness/half_cell
	var result = Array()
	var current_cell = start_cell
	var current_direction = start_direction
	while not (current_cell == start_cell and current_direction == start_direction) or result.size() == 0:
		if not walls_done.has(current_cell):
			walls_done[current_cell] = Array()
		(walls_done[current_cell] as Array).push_back(current_direction)
		# This algorithm follows the wall, keeping it to the righ
		var follow_direction = WorldData.ROTATE_LEFT[current_direction]
		var follow_wall_type = _data.get_wall_type(current_cell, follow_direction)
		var is_internal_corner = follow_wall_type != WorldData.EdgeType.EMPTY
		
		var current_wall_type = _data.get_wall_type(current_cell, current_direction)
		var new_points = Array()
		
		var cell_x = vec_direction[current_direction]
		var cell_y = vec_direction[WorldData.ROTATE_RIGHT[current_direction]]
		
		match current_wall_type:
			_data.EdgeType.EMPTY:	
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
			_data.EdgeType.WALL:
				# ┌   * ┐ - X -1
				#     |  
				#     |    
				# └   | ┘     +1
				# |
				# Z
				#-1    +1
				#forms a straight line, adding a point at *
#				new_points = [Vector2(1.0 - local_margin - local_thickness, -1.0 + end_margin + local_thickness)]
				pass
			_data.EdgeType.HALFDOOR_N:
				var gap = _data.get_wall_meta(current_cell, current_direction)/half_cell - local_margin
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
			_data.EdgeType.HALFDOOR_P:
				var gap = _data.get_wall_meta(current_cell, current_direction)/half_cell - local_margin
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
			_data.EdgeType.DOOR:
				# ┌   * ┐ - X -1
				#     ° 
				#     °    
				# └   | ┘     +1
				# |
				# Z
				#-1    +1
				#forms a straight line, adding a point at *, taking the door(°) edges into account
				var half_gap = _data.get_wall_meta(current_cell, current_direction)*0.5/half_cell - local_margin
				new_points = [
					Vector2(1.0 - local_margin - local_thickness, half_gap),
					Vector2(1.0 - local_margin - local_thickness, -half_gap),
#					Vector2(1.0 - local_margin - local_thickness, -1.0 + end_margin + local_thickness)
				]
		if is_internal_corner:
			new_points.push_back(Vector2(1.0 - local_margin - local_thickness, -1.0 + local_margin + local_thickness))
		var cell_pos = _data.get_cell_position(current_cell)
		var offset = Vector2.ONE*half_cell + Vector2(cell_pos.x, cell_pos.z)
		for p in new_points:
			result.push_back((p.x* cell_x + p.y*cell_y)*half_cell + offset)
		follow_wall_type = _data.get_wall_type(current_cell, follow_direction)
		if follow_wall_type == _data.EdgeType.EMPTY:
			current_direction = WorldData.ROTATE_RIGHT[follow_direction]
			current_cell = _data.get_neighbour_cell(current_cell, follow_direction)
		else:
			current_direction = follow_direction
	return PoolVector2Array(result)
