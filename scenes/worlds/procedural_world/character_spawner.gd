class_name CharacterSpawner
extends Spawner


const ENEMY_GROUP: String = "CULTIST"

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

@export var character_loadout: Array # (Array, Dictionary)
@export var continuous_spawn_level: int = -5
@export var continuous_spawn_max: int = 7   # too many more than 5 can lag the game

var data: WorldData

var _rng := RandomNumberGenerator.new()

@onready var characters_root = Node.new()


func _ready():
	if Engine.is_editor_hint():
		return

	characters_root.name = "CharactersRoot"
	add_child(characters_root, true)


func _physics_process(delta: float) -> void:
	if GameManager.game.current_floor_level <= continuous_spawn_level:
		if get_tree().get_nodes_in_group(ENEMY_GROUP).size() < continuous_spawn_max:
			try_spawn_character_away_from_player()


func try_spawn_character_away_from_player():
	var original_spawn_data = data.get_characters_to_spawn()
	if original_spawn_data.is_empty():
		return
	
	var keys = original_spawn_data.keys()
	var random_key = keys[randi() % keys.size()]
	var original_character_spawn_data = original_spawn_data[random_key] as CharacterSpawnData

	var player = GameManager.game.player
	if not is_instance_valid(player):
		return
	
	# Configure the spawn data with current loadout settings
	original_character_spawn_data.configure_character_loadout(character_loadout)
	original_character_spawn_data.configure_continuous_spawning(continuous_spawn_level, continuous_spawn_max)
	
	# Create a copy for continuous spawning with new positioning
	var spawn_copy := original_character_spawn_data.create_continuous_spawn_copy(data, player.global_position, _rng)
	if not spawn_copy:
		return
	
	_spawn_single_character_with_spawn_data(spawn_copy)
	print("Spawned extra enemy at ", spawn_copy._transforms.front().origin)


## Enhanced character spawning using CharacterSpawnData
func _spawn_single_character_with_spawn_data(spawn_data: CharacterSpawnData) -> void:
	# Configure spawn data with current loadout settings
	spawn_data.configure_character_loadout(character_loadout)
	spawn_data.configure_continuous_spawning(continuous_spawn_level, continuous_spawn_max)
	
	# Spawn character using enhanced spawn data
	var character := spawn_data.spawn_character_in(characters_root)
	if not character:
		print("ERROR CharacterSpawner: Failed to spawn character")


## Legacy method for backward compatibility
## This maintains the original interface while using the new system internally
func _spawn_single_character(spawn_data: CharacterSpawnData):
	_spawn_single_character_with_spawn_data(spawn_data)


## Legacy method for backward compatibility with manual loadout application
## This is kept for any existing code that might call it directly
func _set_random_loadout(character: Node3D) -> void:
	# Create a temporary CharacterSpawnData to handle loadout application
	var temp_spawn_data := CharacterSpawnData.new()
	temp_spawn_data.configure_character_loadout(character_loadout)
	temp_spawn_data._rng = _rng
	temp_spawn_data._apply_character_loadout(character)


## Legacy loadout pack selection method - kept for compatibility
func _get_chosen_pack(total_weight: int, set_index: int) -> Dictionary:
	var temp_spawn_data := CharacterSpawnData.new()
	temp_spawn_data.configure_character_loadout(character_loadout)
	temp_spawn_data._rng = _rng
	return temp_spawn_data._get_chosen_pack(total_weight, set_index)


# Parent GameWorld script connects here.
# CharacterSpawner now only handles continuous spawning
# Initial character spawning is handled by GameWorld._spawn_world_data_objects()
func _on_game_world_generation_finished():
	var setting_generation_seed = GameManager.game.local_settings.get_setting("World Seed")
	if setting_generation_seed is int:
		_rng.seed = setting_generation_seed
	
	data = owner.world_data
	
	# Mark as finished immediately since we don't spawn initial characters anymore
	has_finished_spawning = true
	emit_signal("spawning_finished")
