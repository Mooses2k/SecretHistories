@tool
## Initial Settings Items Generation Step
## Replaces ItemSpawner initial settings logic with unified spawn_data system
## Uses ItemSpawnData and SequentialCellFilter for deterministic spawning
extends GenerationStep

### Member Variables and Dependencies -------------------------------------------------------------
#--- signals --------------------------------------------------------------------------------------

#--- enums ----------------------------------------------------------------------------------------

#--- constants ------------------------------------------------------------------------------------

const ITEM_CENTER_POSITION_OFFSET = Vector3(0.75, 1.0, 0.75)

#--- public variables - order: export > normal var > onready --------------------------------------

#--- private variables - order: export > normal var > onready -------------------------------------

var _rng := RandomNumberGenerator.new()
var _sequential_filter: SequentialCellFilter

### -----------------------------------------------------------------------------------------------


### Built-in Virtual Overrides --------------------------------------------------------------------

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	# Initialize sequential filter for finding free cells
	_sequential_filter = SequentialCellFilter.new()

### -----------------------------------------------------------------------------------------------


### Public Methods --------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

func _execute_step(data: WorldData, gen_data: Dictionary, generation_seed: int) -> void:
	if Engine.is_editor_hint():
		return
	
	# Use world seed for deterministic spawning
	var setting_generation_seed = GameManager.game.local_settings.get_setting("World Seed")
	if setting_generation_seed is int:
		_rng.seed = setting_generation_seed
	else:
		_rng.seed = generation_seed
	
	_generate_initial_settings_items(data)


func _generate_initial_settings_items(data: WorldData) -> void:
	var settings: SettingsClass = GameManager.game.local_settings
	
	for s in settings.get_settings_list():
		var g: String = settings.get_setting_group(s)
		var amount: int = settings.get_setting(s)
		
		if g == "Equipment":
			_spawn_equipment_items(data, s, amount, settings)
		elif g == "Tiny Items":
			_spawn_tiny_items(data, s, amount, settings)


func _spawn_equipment_items(data: WorldData, setting_name: String, amount: int, settings: SettingsClass) -> void:
	for i in amount:
		var available_cells := _sequential_filter.set_max_count(1).filter_cells(data, null, _rng)
		if available_cells.is_empty():
			return
		
		var cell_index: int = available_cells[0]
		var cell_position := CellFilter.get_cell_position(data, cell_index)
		
		# Get the full path from metadata (setting_name is the display name)
		var full_path: String = settings.get_setting_meta(setting_name, "full_path")
		if not full_path:
			# Fallback: assume setting_name is already a full path (for backwards compatibility)
			full_path = setting_name
		
		# Create ItemSpawnData for this equipment item
		var spawn_data := ItemSpawnData.new()
		spawn_data.scene_path = full_path
		spawn_data.amount = 1
		spawn_data.set_center_position_in_cell(cell_position)
		
		# Store spawn data in world data
		data.set_object_spawn_data_to_cell(cell_index, spawn_data)


func _spawn_tiny_items(data: WorldData, setting_name: String, amount: int, settings: SettingsClass) -> void:
	if amount == 0:
		return
	
	var available_cells := _sequential_filter.set_max_count(1).filter_cells(data, null, _rng)
	if available_cells.is_empty():
		return
	
	var cell_index: int = available_cells[0]
	var cell_position := CellFilter.get_cell_position(data, cell_index)
	
	# Get the full path from metadata (setting_name is the display name)
	var full_path: String = settings.get_setting_meta(setting_name, "full_path")
	if not full_path:
		# Fallback: assume setting_name is already a full path (for backwards compatibility)
		full_path = setting_name
	
	# Create ItemSpawnData for tiny item
	var spawn_data := ItemSpawnData.new()
	spawn_data.scene_path = "res://scenes/objects/pickable_items/tiny/_tiny_item.tscn"
	spawn_data.amount = 1
	spawn_data.set_center_position_in_cell(cell_position)
	
	# Set custom properties for tiny item configuration
	spawn_data.set_custom_property("item_data_path", full_path)
	spawn_data.set_custom_property("tiny_item_amount", amount)
	
	# Store spawn data in world data
	data.set_object_spawn_data_to_cell(cell_index, spawn_data)

### -----------------------------------------------------------------------------------------------


### Signal Callbacks ------------------------------------------------------------------------------

### -----------------------------------------------------------------------------------------------
