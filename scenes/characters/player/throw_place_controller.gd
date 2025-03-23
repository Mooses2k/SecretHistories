extends Node

enum ThrowState {
	NONE,
	PLACE,
	THROW,
}

@onready var player_controller: PlayerController = $".."
@onready var player : Player = owner

@export var place_distance : float = 1.5
@export var place_threshold = 0.4
@export var place_blueprint_material : Material


var throw_held_timer_mainhand : float = 0.0
var place_blueprint_mainhand : RigidBody3D
var target_place_transform_mainhand : Transform3D = Transform3D.IDENTITY
var mainhand_item : RigidBody3D = null
var throw_state_mainhand : ThrowState = ThrowState.NONE:
	set(value):
		if throw_state_mainhand == value: return
		if is_instance_valid(place_blueprint_mainhand):
			place_blueprint_mainhand.queue_free()
			place_blueprint_mainhand = null
		throw_state_mainhand = value
		if throw_state_mainhand == ThrowState.PLACE:
			place_blueprint_mainhand = _make_place_blueprint(player.inventory.get_mainhand_item())
			if not is_instance_valid(place_blueprint_mainhand):
				throw_state_mainhand = ThrowState.NONE
				return
			place_blueprint_mainhand.top_level = true
			add_child(place_blueprint_mainhand)


var throw_held_timer_offhand : float = 0.0
var place_blueprint_offhand : RigidBody3D
var target_place_transform_offhand : Transform3D = Transform3D.IDENTITY
var offhand_item : RigidBody3D = null
var throw_state_offhand : ThrowState = ThrowState.NONE:
	set(value):
		if throw_state_offhand == value: return
		if is_instance_valid(place_blueprint_offhand):
			place_blueprint_offhand.queue_free()
			place_blueprint_offhand = null
		throw_state_offhand = value
		if throw_state_offhand == ThrowState.PLACE:
			place_blueprint_offhand = _make_place_blueprint(player.inventory.get_offhand_item())
			if not is_instance_valid(place_blueprint_offhand):
				throw_state_offhand = ThrowState.NONE
				return
			place_blueprint_offhand.top_level = true
			add_child(place_blueprint_offhand)

# reused for collision checks
var _collision : KinematicCollision3D = KinematicCollision3D.new()

func _ready() -> void:
	if not player.is_node_ready():
		await player.ready
	player.inventory.inventory_changed.connect(_on_inventory_changed)

func _process(delta: float) -> void:
	match throw_state_mainhand:
		ThrowState.THROW:
			throw_held_timer_mainhand += delta
			if throw_held_timer_mainhand > place_threshold:
				throw_state_mainhand = ThrowState.PLACE
		ThrowState.PLACE:
			place_blueprint_mainhand.global_basis = player.state.facing.rotated(Vector3.UP, 90)
			target_place_transform_mainhand = _get_place_transform(place_blueprint_mainhand)
			place_blueprint_mainhand.global_transform = target_place_transform_mainhand
			pass
	
	match throw_state_offhand:
		ThrowState.THROW:
			throw_held_timer_offhand += delta
			if throw_held_timer_offhand > place_threshold:
				throw_state_offhand = ThrowState.PLACE
		ThrowState.PLACE:
			place_blueprint_offhand.global_basis = player.state.facing.rotated(Vector3.UP, 90)
			target_place_transform_offhand = _get_place_transform(place_blueprint_offhand)
			place_blueprint_offhand.global_transform = target_place_transform_offhand
			pass
	

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"playerhand|mainhand_throw"):
		mainhand_item = player.inventory.get_mainhand_item()
		if is_instance_valid(mainhand_item):
			throw_held_timer_mainhand = 0.0
			throw_state_mainhand = ThrowState.THROW
	elif event.is_action_released(&"playerhand|mainhand_throw"):
		match throw_state_mainhand:
			ThrowState.THROW:
				player_controller.throw_object(player.inventory.get_mainhand_item())
			ThrowState.PLACE:
				player_controller.place_object(player.inventory.get_mainhand_item(), target_place_transform_mainhand)
		throw_state_mainhand = ThrowState.NONE
	
	if event.is_action_pressed(&"playerhand|offhand_throw"):
		offhand_item = player.inventory.get_offhand_item()
		if is_instance_valid(offhand_item):
			throw_held_timer_offhand = 0.0
			throw_state_offhand = ThrowState.THROW
	elif event.is_action_released(&"playerhand|offhand_throw"):
		match throw_state_offhand:
			ThrowState.THROW:
				player_controller.throw_object(player.inventory.get_offhand_item())
			ThrowState.PLACE:
				player_controller.place_object(player.inventory.get_offhand_item(), target_place_transform_offhand)
		throw_state_offhand = ThrowState.NONE

func _get_place_transform(object : RigidBody3D) -> Transform3D:
	var from_transform := object.global_transform
	from_transform.origin = player_controller.main_camera.global_position
	var move_dir : Vector3 = -player_controller.main_camera.global_basis.z * place_distance
	if object.test_move(from_transform, move_dir * place_distance, _collision):
		move_dir = _collision.get_travel()
	return from_transform.translated(move_dir)

func _make_place_blueprint(object : RigidBody3D) -> RigidBody3D:
	if not is_instance_valid(object): return null
	var blueprint_root := RigidBody3D.new()
	blueprint_root.freeze = true
	blueprint_root.collision_layer = 0
	blueprint_root.collision_mask = object.collision_mask
	if object is PickableItem:
		blueprint_root.collision_mask = object.dropped_mask
	var node_queue : Array[Node] = object.get_children()
	var transform_queue : Array[Transform3D]
	transform_queue.resize(node_queue.size())
	transform_queue.fill(Transform3D.IDENTITY)
	while not node_queue.is_empty():
		var node : Node = node_queue.pop_front() as Node
		var transform : Transform3D = transform_queue.pop_front()
		if node is not Node3D or node.is_in_group(&"NO_BLUEPRINT"):
			continue
		var new_transform : Transform3D = transform * node.transform
		if node.get_parent() == object:
			if node is CollisionShape3D and node.disabled == false:
				var new_node := CollisionShape3D.new()
				new_node.shape = node.shape
				new_node.transform = new_transform
				blueprint_root.add_child(new_node)
			if node is CollisionPolygon3D and node.disabled == false:
				var new_node := CollisionPolygon3D.new()
				new_node.polygon = node.polygon
				new_node.depth = node.depth
				new_node.transform = new_transform
				blueprint_root.add_child(new_node)
		if node is MeshInstance3D and node.visible:
			var new_node := MeshInstance3D.new()
			new_node.mesh = node.mesh
			new_node.material_override = place_blueprint_material
			new_node.transform = new_transform
			blueprint_root.add_child(new_node)
		var children = node.get_children()
		var transforms : Array[Transform3D]
		transforms.resize(children.size())
		transforms.fill(new_transform)
		node_queue.append_array(children)
		transform_queue.append_array(transforms)
	blueprint_root.top_level = true
	return blueprint_root

func _on_inventory_changed() -> void:
	if throw_state_mainhand != ThrowState.NONE:
		if player.inventory.get_mainhand_item() != mainhand_item:
			mainhand_item = null
			throw_state_mainhand = ThrowState.NONE
	if throw_state_offhand != ThrowState.NONE:
		if player.inventory.get_offhand_item() != offhand_item:
			offhand_item = null
			throw_state_offhand = ThrowState.NONE


#func update_throw_state(throw_item : EquipmentItem, delta : float):
	## When the drop button or keys are pressed, grabable objects are released
	#if Input.is_action_just_pressed("playerhand|mainhand_throw") or Input.is_action_just_pressed("playerhand|offhand_throw"):
		#if is_grabbing == true:
			#wants_to_drop = true
			#if grab_object != null:
				#is_grabbing = false
				#grab_press_length = 0.0
				#last_interaction_target = null
				#print("Grab broken by throw")
				#interaction_handled = true
#
				#throw_impulse_and_damage(grab_object)
#
				#wanna_grab = false
#
	#if Input.is_action_just_released("playerhand|mainhand_throw") or Input.is_action_just_released("playerhand|offhand_throw"):
		#wants_to_drop = false
#
	#if throw_state == ThrowState.PRESSING:
		#throw_item = character.inventory.get_mainhand_item() if throw_item_hand == ItemSelection.ITEM_MAINHAND else character.inventory.get_offhand_item()
		##throw_item.set_item_state(GlobalConsts.ItemState.DROPPED)
#
		## Shows the object blueprint in the world
		#if throw_press_length > hold_time_to_grab:
			#if _placing_blueprint == null:
				#_placing_blueprint = throw_item.duplicate()
				##var _placing_blueprint_mesh: MeshInstance3D = _placing_blueprint.get_node("MeshInstance3D") # TODO: this is not going to be reliable
				## Check all MeshInstances in the item scene until we find the first non-null one, and use that for the blueprint shader
				#var queue : Array[Node] = _placing_blueprint.get_children()
				#while not queue.is_empty():
					#var _placing_blueprint_mesh = queue.pop_front()
					#queue.append_array(_placing_blueprint_mesh.get_children())
					#print(_placing_blueprint_mesh)
					#if _placing_blueprint_mesh is MeshInstance3D:
						#if _placing_blueprint_mesh.mesh:
							#prints("_placing_blueprint_mesh that's not empty:", _placing_blueprint_mesh)
							#_placing_blueprint_mesh.set_material_override(should_place_blueprint_shader)
#
			#if _placing_blueprint:
				#current_control_mode.aimcast.add_exception(_placing_blueprint)
				#for child in _placing_blueprint.get_children():
					#if child is RigidBody3D or child is Area3D or child is StaticBody3D:
						#current_control_mode.aimcast.add_exception(child)
#
				#var origin : Vector3 = owner.drop_position_node.global_transform.origin
				#var end : Vector3 = current_control_mode.get_target_placement_position()
				#var dir : Vector3 = end - origin
				#dir = dir.normalized() * min(dir.length(), max_placement_distance)
#
				#var motion_params = PhysicsTestMotionParameters3D.new()
				#motion_params.from = owner.drop_position_node.global_transform
				#motion_params.motion = dir
#
				#var result = PhysicsTestMotionResult3D.new()
				#var collision_happened: bool = PhysicsServer3D.body_test_motion(_placing_blueprint.get_rid(), motion_params, result)
#
				#if _placing_blueprint.get_parent() == null:
					#owner.add_child(_placing_blueprint)
				#var new_position: Vector3 = origin + result.get_travel()
				#_placing_blueprint.global_transform.origin = new_position
				#_placing_blueprint.rotation = owner.drop_position_node.rotation
#
	## Place item upright on pointed-at surface or, if no surface in range, simply drop in front of player
	#if throw_state == ThrowState.SHOULD_PLACE:
		#print("Should place rather than throw item")
		#_placing_blueprint.queue_free()
		#_placing_blueprint = null
		#throw_item = character.inventory.get_mainhand_item() if throw_item_hand == ItemSelection.ITEM_MAINHAND else character.inventory.get_offhand_item()
		#throw_item.set_item_state(GlobalConsts.ItemState.DROPPED)
		#if throw_item:
			## Calculates where to place the item
			#var origin : Vector3 = owner.drop_position_node.global_transform.origin
			#var end : Vector3 = current_control_mode.get_target_placement_position()
			#var dir : Vector3 = end - origin
			#dir = dir.normalized() * min(dir.length(), max_placement_distance)
			#var layers = throw_item.collision_layer
			#var mask = throw_item.collision_mask
			#throw_item.collision_layer = throw_item.dropped_layers
			#throw_item.collision_mask = throw_item.dropped_mask
			#var result = PhysicsTestMotionResult3D.new()
			## The return value can be ignored, since extra information is put into the 'result' variable
			#var motion_params = PhysicsTestMotionParameters3D.new()
			#motion_params.from = owner.drop_position_node.global_transform
			#motion_params.motion = dir
#
			#PhysicsServer3D.body_test_motion(throw_item.get_rid(), motion_params, result)
			#throw_item.collision_layer = layers
			#throw_item.collision_mask = mask
			#if result.get_travel().length() > 0.1:
				#if throw_item_hand == ItemSelection.ITEM_MAINHAND:
					#character.inventory.drop_mainhand_item()
				#else:
					#character.inventory.drop_offhand_item()
				#throw_item.call_deferred("global_translate", result.get_travel()) # TODO: Is this the line causing the hanging delay in air, after placing items sometimes?
#
	## Always test Left-Clicking twice with a bomb in main hand after changing anything here. Bomb throws are an edge case of throw as they don't have to happen with the usual throw keys.
	#elif throw_state == ThrowState.SHOULD_THROW:
		#if _placing_blueprint:
			#_placing_blueprint.queue_free()
			#_placing_blueprint = null
#
		#print("Should throw")
		#if throw_item:   # This is a lit bomb that has already set itself as throw_item
			#if throw_item == character.inventory.get_mainhand_item():
				#throw_item_hand = ItemSelection.ITEM_MAINHAND
			#else:
				#throw_item_hand = ItemSelection.ITEM_OFFHAND
#
		#if !throw_item:   # If the throw item hasn't already been selected, which should be all cases except use_primary of a lit bomb.
			#if throw_item_hand == ItemSelection.ITEM_MAINHAND:
				#throw_item = character.inventory.get_mainhand_item()
			#else:
				#throw_item = character.inventory.get_offhand_item()
#
		## At this point, throw_item_hand is determined, whether this is a throw-button throw or a use_primary bomb throw
		#if throw_item:
			#throw_item.set_item_state(GlobalConsts.ItemState.DAMAGING)
			#if throw_item_hand == ItemSelection.ITEM_MAINHAND:
				#character.inventory.drop_mainhand_item()
			#else:
				#character.inventory.drop_offhand_item()
#
			#throw_impulse_and_damage(throw_item)
#
	## throw_state defined here, will this get wiped by the physics_process nulling of throw_item?
	#match throw_state:
		#ThrowState.IDLE:
			#if Input.is_action_just_pressed("playerhand|mainhand_throw") and owner.inventory.get_mainhand_item() and is_grabbing == false and owner.is_reloading == false:
				#throw_item_hand = ItemSelection.ITEM_MAINHAND
				#throw_state = ThrowState.PRESSING
				#throw_press_length = 0.0
			#elif Input.is_action_just_pressed("playerhand|offhand_throw") and owner.inventory.get_offhand_item() and is_grabbing == false and owner.is_reloading == false:
				#throw_item_hand = ItemSelection.ITEM_OFFHAND
				#throw_state = ThrowState.PRESSING
				#throw_press_length = 0.0
		#ThrowState.PRESSING:
			#if Input.is_action_pressed("playerhand|mainhand_throw" if throw_item_hand == ItemSelection.ITEM_MAINHAND else "playerhand|offhand_throw"):
				#throw_press_length += delta
			#else:
				#throw_state = ThrowState.SHOULD_PLACE if throw_press_length > hold_time_to_grab else ThrowState.SHOULD_THROW
		#ThrowState.SHOULD_PLACE, ThrowState.SHOULD_THROW:
			#throw_state = ThrowState.IDLE
