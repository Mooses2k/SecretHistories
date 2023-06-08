tool
class_name CharacterSpawner
extends Node


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

export var max_count = 5

var data : WorldData

onready var characters_root = Node.new()

var _rng := RandomNumberGenerator.new()

var _density_by_type := {
	WorldData.CellType.ROOM: 0.01,
	WorldData.CellType.CORRIDOR: 0.0025,
	WorldData.CellType.HALL: 0.005,
}
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
	var count = 0
	print("Spawning characters")
	
	var valid_cells := []
	for type in _density_by_type.keys():
		valid_cells.append_array(data.get_cells_for(type))
	valid_cells.sort()
	
	for cell_index in valid_cells:
		if count >= max_count:
			break
		
		var cell_type = data.get_cell_type(cell_index)
		if _rng.randf() < _density_by_type[cell_type]:
			count += 1
			_spawn_character_at(cell_index)
	
	print("Total Characters Spawned: %s"%[count])


func _spawn_character_at(cell_index: int) -> void:
	var character = character_scene.instance() as Spatial
	var cell_coordinates := data.get_local_cell_position(cell_index)
	character.translation = cell_coordinates
	characters_root.add_child(character)
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


func _on_ProceduralWorld_generation_finished():
	var setting_generation_seed = GameManager.game.local_settings.get_setting("World Seed")
	if setting_generation_seed is int:
		_rng.seed = setting_generation_seed
	
	data = owner.world_data
	call_deferred("spawn_characters")


###################################################################################################
### Editor Code ###################################################################################
###################################################################################################

const GROUP_PREFIX_DENSITY = "density_"
const PERCENT_CONVERSION = 100.0


func _get_property_list() -> Array:
	var properties := [
		{
			name = "_density_by_type",
			type = TYPE_DICTIONARY,
			usage = PROPERTY_USAGE_STORAGE,
		},
		{
			name = "Density by Cell Type",
			type = TYPE_NIL,
			usage = PROPERTY_USAGE_GROUP,
			hint_string = GROUP_PREFIX_DENSITY
		},
	]
	
	for type in ["room", "corridor", "hall"]:
		properties.append({
			name = GROUP_PREFIX_DENSITY + type,
			type = TYPE_REAL,
			usage = PROPERTY_USAGE_EDITOR,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0,100.0,0.05"
		})
	
	return properties


func _get(property: String):
	var value
	
	if property.begins_with(GROUP_PREFIX_DENSITY):
		var type := property.replace(GROUP_PREFIX_DENSITY, "")
		match type:
			"room":
				value = _density_by_type[WorldData.CellType.ROOM] * PERCENT_CONVERSION
			"corridor":
				value = _density_by_type[WorldData.CellType.CORRIDOR] * PERCENT_CONVERSION
			"hall":
				value = _density_by_type[WorldData.CellType.HALL] * PERCENT_CONVERSION
			_:
				push_error("Unindentified density type: %s"%[type])
	
	return value


func _set(property: String, value) -> bool:
	var has_handled = false
	
	if property.begins_with(GROUP_PREFIX_DENSITY):
		var type := property.replace(GROUP_PREFIX_DENSITY, "")
		var index := -1
		match type:
			"room":
				index = WorldData.CellType.ROOM
			"corridor":
				index = WorldData.CellType.CORRIDOR
			"hall":
				index = WorldData.CellType.HALL
			_:
				push_error("Unindentified density type: %s"%[type])
		
		if index > -1:
			var final_value = value / PERCENT_CONVERSION
			_density_by_type[index] = final_value
			has_handled = true
	
	return has_handled

### END of Editor Code ############################################################################
