extends Spatial
class_name GameWorld

signal grid_data_changed(grid_size, cell_size , grid_data)

const Ghost = preload("res://Characters/Monster.tscn")
const CELL_SIZE = 2

export var grid_size : int = 48
export var steps_to_walk = 200

var grid_data : Array = []
var wallx_basis : Basis = Basis.IDENTITY.rotated(Vector3.UP, deg2rad(90))

# Make this an array later
var floor_index = 0
var wall_index = 1

onready var floor_map : GridMap = $Gridmaps/Floor as GridMap
onready var wallx_map : GridMap = $Gridmaps/WallsX as GridMap
onready var wallz_map : GridMap = $Gridmaps/WallsZ as GridMap
onready var navigation : Navigation = $Gridmaps as Navigation
#onready var monster = $GridMap/Monster
#onready var player = $Player

func _ready():
	randomize()
	generate_world()

func generate_world():
	generate_data()
	generate_mesh()

func generate_data():
	grid_data.resize(grid_size)
	for i in grid_data.size():
		grid_data[i] = []
		grid_data[i].resize(grid_size)
		for j in grid_data[i].size():
			grid_data[i][j] = false

	var borders = Rect2(0, 0, grid_size, grid_size)
	var walker = Walker.new(Vector2(grid_size / 2, grid_size / 2), borders)
	var map = walker.walk(steps_to_walk)

	var cell_position = walker.get_end_room().position
	var world_position = Vector3(cell_position.x + 0.5, 0, cell_position.y + 0.5) * CELL_SIZE

	walker.queue_free()
	for location in map:
		grid_data[location.x][location.y] = true
		
	spawn_monsters(world_position)
	emit_signal("grid_data_changed", grid_size, CELL_SIZE, grid_data)
func generate_mesh():
	for i in grid_data.size():
		for j in grid_data[i].size():
			if grid_data[i][j] == true:
				floor_map.set_cell_item(i, 0, j, floor_index)
				if i - 1 < 0 or grid_data[i - 1][j] == false:
					wallx_map.set_cell_item(i, 0, j, wall_index, wallx_basis.get_orthogonal_index())
				if i + 1 > grid_size - 1 or grid_data[i + 1][j] == false:
					wallx_map.set_cell_item(i + 1, 0, j, wall_index, wallx_basis.get_orthogonal_index())
				if j - 1 < 0 or grid_data[i][j - 1] == false:
					wallz_map.set_cell_item(i, 0, j, wall_index)
				if j + 1 > grid_size - 1 or grid_data[i][j + 1] == false:
					wallz_map.set_cell_item(i, 0, j + 1, wall_index)
			else:
				pass

func spawn_monsters(location):
#	if (randi() % 60 < 1):
#		for room in rooms:  #issue is here I think, as 'room' is only defined here not the previous definition!
#			var number_of_monsters_to_spawn = 1   # randi() % 1 + 1 #change first number to number of bats per bunch
#			for m in number_of_monsters_to_spawn:
				var ghost = Ghost.instance()
				add_child(ghost)
				ghost.translation = location
				print("Ghost spawned at: ", ghost.translation)
