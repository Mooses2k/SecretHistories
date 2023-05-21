extends Node
class_name CharacterSpawner


export var character_scene : PackedScene

# Represents the possible character loadouts, with the following structure:
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
export(Array, Dictionary) var character_loadout : Array
export var density = 0.05
export var max_count = 5

var data : WorldData

onready var characters_root = Node.new()


func _ready():
	add_child(characters_root)


func spawn_characters():
	for child in characters_root.get_children():
		child.queue_free()
	var count = 0
	print("Spawning characters")
	for i in data.get_size_x():
		for j in data.get_size_z():
			if count >= max_count:
				return
			var cell = data.get_cell_index_from_int_position(i, j)
			if data.get_cell_type(cell) == data.CellType.ROOM and randf()<density:
				count += 1
				var character = character_scene.instance() as Spatial
				character.translation = GameManager.game.level.grid_to_world(Vector3(i, 0, j))
				characters_root.add_child(character)
				var inventory = character.get_node("Inventory")
				for set_index in character_loadout.size():
					var total_weight = 0
					for pack in (character_loadout[set_index] as Dictionary).keys():
						total_weight += character_loadout[set_index][pack]
					if total_weight == 0:
						continue

					var rng = randi()%total_weight

					var cummulative_weight = 0
					var chosen_pack = null
					for pack in (character_loadout[set_index] as Dictionary).keys():
						cummulative_weight += character_loadout[set_index][pack]
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


func _on_ProceduralWorld_generation_finished():
	data = owner.world_data
	spawn_characters()
