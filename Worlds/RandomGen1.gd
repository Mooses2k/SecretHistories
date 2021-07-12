extends Node2D

#const Player = preload("res://Player/Player.tscn")
#const Exit = preload("res://World/ExitStair.tscn")
const Ghost = preload("res://Characters/Monster.tscn")
const CELL_SIZE = 2

#export(Vector2) var player_spawn_location = Vector2(26 * 32, 18 * 32)
export var steps_to_walk = 200

#need to instead figure this out programmatically once have different size rooms
var borders = Rect2(1, 1, 52, 37)


#onready var tileMap = $TileMap

func _ready():
	randomize()
	generate_level()

func generate_level():
	var walker = Walker.new(Vector2(26, 18), borders)
	var map = walker.walk(steps_to_walk)
	var cell_position = walker.get_end_room().position
	var world_position = Vector3(cell_position.x + 0.5, 0, cell_position.y + 0.5) * CELL_SIZE
#	var exit = Exit.instance()
#	add_child(exit)
	#alt is walker.rooms.back().position * 32
#	exit.position = walker.get_end_room().position * 32
#	var exit = # Need instance of Exit stair or something with .position here
#	exit.position = walker.get_end_room().position * CELL_SIZE
#	exit.connect("leaving_level", self, "reload_level")
	
	walker.queue_free()
#	for location in map:
	spawn_monsters(world_position)  # location)

func spawn_monsters(location):
#	if (randi() % 60 < 1):
#		for room in rooms:  #issue is here I think, as 'room' is only defined here not the previous definition!
#			var number_of_monsters_to_spawn = 1   # randi() % 1 + 1 #change first number to number of bats per bunch
#			for m in number_of_monsters_to_spawn:
				var ghost = Ghost.instance()
				add_child(ghost)
				ghost.position = location
				print(ghost.position)

func reload_level():
	get_tree().reload_current_scene()

