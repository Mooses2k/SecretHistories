extends Node
export var enemy_scene : PackedScene
export var density = 0.05

onready var enemies_root = Node.new()

func _ready():
	add_child(enemies_root)

func _on_World_world_data_changed(new_data, new_size):
	for child in enemies_root.get_children():
		child.queue_free()
	for i in new_size:
		for j in new_size:
			if new_data[i][j] and randf()<density:
				var enemy = enemy_scene.instance() as Spatial
				enemy.translation = GameManager.game.level.grid_to_world(Vector3(i, 0, j))
				enemies_root.add_child(enemy)
				
