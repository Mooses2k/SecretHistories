# Write your doc string for this file here
extends Node2D

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const COLOR_DELAUNAY = Color.cyan
const COLOR_CONNECTIONS = Color.yellowgreen

#--- public variables - order: export > normal var > onready --------------------------------------

export(float, 0.0, 10.0, 0.5) var distances_scale := 10.0

var room_centers_cell_indexes := PoolIntArray()
var room_centers := PoolVector2Array() setget _set_room_centers
var delaunay := PoolIntArray() setget _set_delaunay
var room_connections := {} setget _set_room_connections

#--- private variables - order: export > normal var > onready -------------------------------------

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _draw() -> void:
	for point in room_centers:
		draw_circle(point, 3.0, COLOR_DELAUNAY)
	
	for index in range(0, delaunay.size(), 3):
		var vertice_a := room_centers[delaunay[index]]
		var vertice_b := room_centers[delaunay[index + 1]]
		var vertice_c := room_centers[delaunay[index + 2]]
		
		draw_line(vertice_a, vertice_b, COLOR_DELAUNAY)
		draw_line(vertice_b, vertice_c, COLOR_DELAUNAY)
		draw_line(vertice_c, vertice_a, COLOR_DELAUNAY)
	
	for cell_index in room_connections:
		var from_index := room_centers_cell_indexes.find(cell_index)
		var from_position := room_centers[from_index]
		for connected_cell_index in room_connections[cell_index]:
			var to_index := room_centers_cell_indexes.find(connected_cell_index)
			var to_position := room_centers[to_index]
			
			draw_line(from_position, to_position, COLOR_CONNECTIONS)
	

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _set_room_centers(value: PoolVector2Array) -> void:
	room_centers = value
	if not room_centers.empty() and is_inside_tree():
		for index in room_centers.size():
			var point := room_centers[index]
			room_centers[index] = point * distances_scale
		
		update()


func _set_delaunay(value: PoolIntArray) -> void:
	delaunay = value
	if not delaunay.empty() and is_inside_tree():
		update()


func _set_room_connections(value: Dictionary) -> void:
	room_connections = value.duplicate(true)
	if not room_connections.empty() and is_inside_tree():
		print("room indexes: %s"%[room_centers_cell_indexes])
		print("room_connections: %s"%[room_connections])
		update()

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
