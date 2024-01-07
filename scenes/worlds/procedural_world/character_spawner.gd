class_name CharacterSpawner
extends Spawner


const ENEMY_GROUP : String = "CULTIST"

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
export var continuous_spawn_level : int = -5
export var continuous_spawn_max : int = 5

var data : WorldData

var _rng := RandomNumberGenerator.new()

var _total_weights_by_set := []

onready var characters_root = Node.new()


func _ready():
	if Engine.editor_hint:
		return
	
	characters_root.name = "CharactersRoot"
	add_child(characters_root, true)
	
	_total_weights_by_set.resize(character_loadout.size())
	for set_index in character_loadout.size():
		var set_weight := 0
		for pack in (character_loadout[set_index] as Dictionary).keys():
			set_weight += character_loadout[set_index][pack]
		
		_total_weights_by_set[set_index] = set_weight


func _physics_process(delta: float) -> void:
	if GameManager.game.current_floor_level <= continuous_spawn_level:
		if get_tree().get_nodes_in_group(ENEMY_GROUP).size() < continuous_spawn_max:
			try_spawn_character_away_from_player()


func spawn_characters():
	for child in characters_root.get_children():
		child.queue_free()
	
	print("Spawning characters")
	var characters_by_index := data.get_characters_to_spawn()
	for cell_index in characters_by_index:
		var spawn_data := characters_by_index[cell_index] as CharacterSpawnData
		_spawn_single_character(spawn_data)
	
	print("Total Characters Spawned: %s"%[characters_by_index.size()])
	has_finished_spawning = true
	emit_signal("spawning_finished")


func try_spawn_character_away_from_player():
	var original_spawn_data = data.get_characters_to_spawn()
	if original_spawn_data.empty():
		return
	var keys = original_spawn_data.keys()
	var random_key = keys[randi()%keys.size()]
	var random_spawn_data = original_spawn_data[random_key].duplicate()
	
	var player = GameManager.game.player
	if not is_instance_valid(player):
		return
	var player_pos = player.global_translation
	var player_cell = data.get_cell_index_from_local_position(player_pos)
	var player_int_coords = data.get_int_position_from_cell_index(player_cell)
	var try_pos : Vector3 = Vector3(data.world_size_x - 1, 0, data.world_size_z - 1)
	
	if player_int_coords[0] > data.world_size_x/2:
		try_pos.x = 0
	if player_int_coords[1] > data.world_size_z/2:
		try_pos.z = 0
	
	try_pos = data.get_local_cell_position(data.get_cell_index_from_int_position(try_pos.x, try_pos.z))
	try_pos = NavigationServer.map_get_closest_point(owner.get_world().navigation_map, try_pos)
	try_pos = data.get_local_cell_position(data.get_cell_index_from_local_position(try_pos))
	
	random_spawn_data.set_center_position_in_cell(try_pos)
	_spawn_single_character(random_spawn_data)
	print("Spawned extra enemy at ", try_pos)


func _spawn_single_character(spawn_data : CharacterSpawnData):
	var character := spawn_data.spawn_character_in(characters_root)
	_set_random_loadout(character)


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


# Parent GameWorld script connects here.
func _on_game_world_generation_finished():
	var setting_generation_seed = GameManager.game.local_settings.get_setting("World Seed")
	if setting_generation_seed is int:
		_rng.seed = setting_generation_seed
	
	data = owner.world_data
	call_deferred("spawn_characters")
