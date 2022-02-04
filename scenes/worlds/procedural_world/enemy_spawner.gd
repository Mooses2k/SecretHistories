extends Node
class_name EnemySpawner

export var enemy_scene : PackedScene

# Represents the possible enemy loadouts, with the following structure:
# Loadout:
# [
#	set 1,
#	set 2,
#	set 3,
# ]
# In which each set is a dictionary following the scheme:
# Set:
# {
#	Pack 1 : weight 1,
#	Pack 2 : weight 2,
# 	Pack 3 : weight 3,
# }
# Each pack, represents a selection of items that, if chosen, will all be
# chosen together, in the following way:
# Pack:
# {
#	Item 1 : Vector2(Range minimum, Range maximum),
#	Item 2 : Vector2(Range minimum, Range maximum),
#	Item 3 : Vector2(Range minimum, Range maximum)
# }
#
# The loadout selector works in the following manner:
# First, for each set in the main array, one pack is selected,
# the probabilities being based on the weight of each pack within the set.
# Then, each item in the pack is added to the characters inventory,
# following the range setting in a contextual manner:
#
# Tiny items and other stackable will be added in a random amount within the range
#
# Non stackable items will deal with the range in different ways:
# Guns, for example, will be added to the inventory loaded with
# a random amount of ammunition within the selected range
#
export(Array, Dictionary) var enemy_loadout : Array
export var density = 0.05

onready var enemies_root = Node.new()

func _ready():
	add_child(enemies_root)

func _on_World_world_data_changed(new_data, new_size):
	for child in enemies_root.get_children():
		child.queue_free()
	print("Spawning enemies")
	for i in new_size:
		for j in new_size:
			if new_data[i][j] and randf()<density:
				var enemy = enemy_scene.instance() as Spatial
				enemy.translation = GameManager.game.level.grid_to_world(Vector3(i, 0, j))
				enemies_root.add_child(enemy)
				var inventory = enemy.get_node("Inventory")
				for set_index in enemy_loadout.size():
					var total_weight = 0
					for pack in (enemy_loadout[set_index] as Dictionary).keys():
						total_weight += enemy_loadout[set_index][pack]
					if total_weight == 0:
						continue

					var rng = randi()%total_weight

					var cummulative_weight = 0
					var chosen_pack = null
					for pack in (enemy_loadout[set_index] as Dictionary).keys():
						cummulative_weight += enemy_loadout[set_index][pack]
						if rng < cummulative_weight:
							chosen_pack = pack
							break
					chosen_pack = chosen_pack as Dictionary
					for item in chosen_pack.keys():
						var amount : int = chosen_pack[item].x
						if chosen_pack[item].y > chosen_pack[item].x:
							amount += randi()%(int(1 + chosen_pack[item].y - chosen_pack[item].x))
						if item is TinyItemData:
							if not inventory.tiny_items.has(item):
								inventory.tiny_items[item] = 0
							inventory.tiny_items[item] += amount
							pass
						elif item is PackedScene:
							var instanced = item.instance()
							if instanced is PickableItem:
								inventory.add_item(instanced)
								instanced.set_range(chosen_pack[item])
#								print("Added to hotbar")
							else:
								instanced.free()
#				print(inventory.hotbar)
#				print(inventory.tiny_items)
