extends GameWorld

const Ghost = preload("res://scenes/characters/enemies/ghost/ghost.tscn")

export var grid_size : int = 48
export var steps_to_walk = 200

onready var gridmaps = $Gridmaps

func _ready():
	self.navigation = $Gridmaps as Navigation
	randomize()
	generate_world()

# player spawns in the center
func get_player_spawn_position() -> Vector3:
	var result = self.grid_to_world((Vector3.ONE*0.5*grid_size).floor())
	print("player spawn : ", result)
	return result

func generate_world():
	generate_data()
	gridmaps.generate_mesh(self.world_data, self.world_size)

func generate_data():
	var grid_data : Array = []
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
	self.set_world_data(grid_data)


func spawn_monsters(location):
#	if (randi() % 60 < 1):
#		for room in rooms:  #issue is here I think, as 'room' is only defined here not the previous definition!
#			var number_of_monsters_to_spawn = 1   # randi() % 1 + 1 #change first number to number of bats per bunch
#			for m in number_of_monsters_to_spawn:
				var ghost = Ghost.instance()
				ghost.translation = location
				call_deferred("add_child", ghost)
				print("Ghost spawned at: ", ghost.translation)
