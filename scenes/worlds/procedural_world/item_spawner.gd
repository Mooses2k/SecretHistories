@tool
class_name ItemSpawner
extends Spawner

# This is a tool so that `_min_loot` and `_max_loot` setters can act as data validators when
# changing values in the editor


const ITEM_POSITION_OFFSET = Vector3(0.75, 1.0, 0.75)

var _rng := RandomNumberGenerator.new()
var _used_cell_indexes := []
var _sequential_filter: SequentialCellFilter

### Built in Engine Methods -----------------------------------------------------------------------

func _ready() -> void:
	if Engine.is_editor_hint():
		return

### -----------------------------------------------------------------------------------------------


### Private Methods -------------------------------------------------------------------------------

# Parent GameWorld script connects here.
func _on_game_world_generation_finished():
	var setting_generation_seed = GameManager.game.local_settings.get_setting("World Seed")
	if setting_generation_seed is int:
		_rng.seed = setting_generation_seed
	
	var data := owner.world_data as WorldData
	_spawn_initial_settings_items(data)
	_spawn_world_data_objects(data)
	
	has_finished_spawning = true
	emit_signal("spawning_finished")


func _spawn_world_data_objects(data: WorldData) -> void:
	var objects_to_spawn := data.get_objects_to_spawn()
	
	for cell_index in objects_to_spawn:
		var spawn_data := objects_to_spawn[cell_index] as SpawnData
		
		var children_before := owner.get_child_count()
		spawn_data.spawn_item_in(owner, true)  # Enable logging
		var children_after := owner.get_child_count()
		
		if children_after > children_before:
			var new_child := owner.get_child(children_after - 1)
			
			# Check if it's a wall object and log its state
			if new_child.get_node_or_null("WallAttachmentComponent"):
				call_deferred("_debug_wall_object_state", new_child)


func _spawn_initial_settings_items(data : WorldData):
	var settings : SettingsClass = GameManager.game.local_settings
	
	# Initialize sequential filter for finding free cells
	_sequential_filter = SequentialCellFilter.new()
	
	for s in settings.get_settings_list():
		var g = settings.get_setting_group(s)
		var amount = settings.get_setting(s)
		
		if g == "Equipment":
			for i in amount:
				var available_cells := _sequential_filter.set_max_count(1).filter_cells(data, null, _rng)
				if available_cells.is_empty():
					return
				
				var cell_index: int = available_cells[0]
				_used_cell_indexes.append(cell_index)
				# Use CellFilter helper function instead of direct WorldData call
				var cell_pos = CellFilter.get_cell_position(data, cell_index) + ITEM_POSITION_OFFSET
				
				# Get the full path from metadata (s is the display name)
				var full_path = settings.get_setting_meta(s, "full_path")
				if full_path:
					_spawn_item(full_path, cell_pos)
				else:
					# Fallback: assume s is already a full path (for backwards compatibility)
					_spawn_item(s, cell_pos)
		elif g == "Tiny Items":
			if amount == 0:
				continue
			var available_cells := _sequential_filter.set_max_count(1).filter_cells(data, null, _rng)
			if available_cells.is_empty():
				return
			
			var cell_index: int = available_cells[0]
			_used_cell_indexes.append(cell_index)
			# Use CellFilter helper function instead of direct WorldData call
			var pos = CellFilter.get_cell_position(data, cell_index) + ITEM_POSITION_OFFSET
			
			# Get the full path from metadata (s is the display name)
			var full_path = settings.get_setting_meta(s, "full_path")
			if full_path:
				_spawn_tiny_item(full_path, amount, pos)
			else:
				# Fallback: assume s is already a full path (for backwards compatibility)
				_spawn_tiny_item(s, amount, pos)


# Angle is in radians
func _spawn_item(scene_path: String, position: Vector3, angle := 0.0) -> void:
	var item
	var item_scene : PackedScene = load(scene_path)
	item = item_scene.instantiate()
	
	if item is Node3D:
		(item as Node3D).position = position
		(item as Node3D).rotate_y(angle)
	
	owner.add_child(item)
	
	# Having this here instead of ready() function of light fixes blueprint SHOULD_PLACE candle emissive material bug	
	if item is CandleItem or item is CandelabraItem:
		item.light()
	
#	print("item spawned: %s | at: %s | rotated y by: %s"%[scene_path, position, angle])


func _spawn_tiny_item(item_data_path: String, amount: int, position: Vector3) -> void:
	var tiny_item_scene = preload("res://scenes/objects/pickable_items/tiny/_tiny_item.tscn")
	var item : TinyItem = tiny_item_scene.instantiate()
	item.amount = amount
	item.item_data = load(item_data_path)
	item.position = position
	owner.add_child(item)


func _debug_wall_object_state(wall_object: Node3D) -> void:
	print("=== WALL OBJECT STATE DEBUG ===")
	print("WALL DEBUG: Object name: %s" % wall_object.name)
	print("WALL DEBUG: Global position: %s" % wall_object.global_position)
	
	# Check if it's a RigidBody3D and log physics state
	if wall_object is RigidBody3D:
		var rigid_body := wall_object as RigidBody3D
		print("WALL DEBUG: RigidBody3D - Gravity: %f, Sleeping: %s" % [
			rigid_body.gravity_scale, rigid_body.sleeping
		])
		print("WALL DEBUG: Linear velocity: %s" % rigid_body.linear_velocity)
	
	# Check for wall attachment component
	var wall_attachment := wall_object.get_node_or_null("WallAttachmentComponent")
	if wall_attachment:
		print("WALL DEBUG: Found WallAttachmentComponent")
		print("WALL DEBUG: Wall direction: %d" % wall_attachment.wall_direction)
		print("WALL DEBUG: Is attached: %s" % wall_attachment.is_attached_to_wall)
		print("WALL DEBUG: Auto setup: %s" % wall_attachment.auto_setup_attachment)
	else:
		print("WALL DEBUG ERROR: No WallAttachmentComponent found!")
	
	print("=== END WALL OBJECT DEBUG ===")

### -----------------------------------------------------------------------------------------------
