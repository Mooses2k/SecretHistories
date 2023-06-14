class_name CharacterSpawner
extends Node


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

var data : WorldData

onready var characters_root = Node.new()

var _rng := RandomNumberGenerator.new()

var _total_weights_by_set := []


func _ready():
	if Engine.editor_hint:
		return
	
	add_child(characters_root)
	
	_total_weights_by_set.resize(character_loadout.size())
	for set_index in character_loadout.size():
		var set_weight := 0
		for pack in (character_loadout[set_index] as Dictionary).keys():
			set_weight += character_loadout[set_index][pack]
		
		_total_weights_by_set[set_index] = set_weight


func spawn_characters():
	for child in characters_root.get_children():
		child.queue_free()
	
	print("Spawning characters")
	var characters_by_index := data.get_characters_to_spawn()
	for cell_index in characters_by_index:
		var spawn_data := characters_by_index[cell_index] as CharacterSpawnData
		var cell_coordinates := data.get_local_cell_position(cell_index)   # var never used
		var character := spawn_data.spawn_character_in(characters_root)
		_set_random_loadout(character)
	
	print("Total Characters Spawned: %s"%[characters_by_index.size()])


func _set_random_loadout(character: Spatial) -> void:
	var inventory = character.get_node("Inventory")
	for set_index in character_loadout.size():
		var total_weight := _total_weights_by_set[set_index] as int
		if total_weight == 0:
			continue
		
		var chosen_pack := _get_chosen_pack(total_weight, set_index)
		for item in chosen_pack.keys():
			var min_amount := chosen_pack[item].x as int
			var max_amount := chosen_pack[item].y as int
			var amount = min_amount
			if max_amount > min_amount:
				amount = _rng.randi() % (max_amount - min_amount) +  min_amount
			
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
#					print("Added to hotbar")
				else:
					instanced.free()
#	print(inventory.hotbar)
#	print(inventory.tiny_items)


func _get_chosen_pack(total_weight: int, set_index: int) -> Dictionary:
	var value := {}
	
	var rng = _rng.randi()%total_weight
	var cummulative_weight = 0
	for pack in (character_loadout[set_index] as Dictionary).keys():
		cummulative_weight += character_loadout[set_index][pack]
		if rng < cummulative_weight:
			value = pack
			break
	
	return value


func _on_ProceduralWorld_generation_finished():
	var setting_generation_seed = GameManager.game.local_settings.get_setting("World Seed")
	if setting_generation_seed is int:
		_rng.seed = setting_generation_seed
	
	data = owner.world_data
	call_deferred("spawn_characters")
