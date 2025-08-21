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

# Mousewheel distance control (similar to grab system)
@export var place_distance_min : float = 0.3
@export var place_distance_max : float = 1.5
@export var place_distance_increment : float = 0.1

# Track mousewheel mode state
var mousewheel_mode_mainhand : bool = false
var locked_distance_mainhand : float = 0.0
var mousewheel_mode_offhand : bool = false
var locked_distance_offhand : float = 0.0

@export var place_origin : Node3D
@export var throw_origin : Node3D

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
			target_place_transform_mainhand = _get_place_transform(place_blueprint_mainhand, true)  # true = mainhand
			place_blueprint_mainhand.global_transform = target_place_transform_mainhand
			pass

	match throw_state_offhand:
		ThrowState.THROW:
			throw_held_timer_offhand += delta
			if throw_held_timer_offhand > place_threshold:
				throw_state_offhand = ThrowState.PLACE
		ThrowState.PLACE:
			place_blueprint_offhand.global_basis = player.state.facing.rotated(Vector3.UP, 90)
			target_place_transform_offhand = _get_place_transform(place_blueprint_offhand, false)  # false = offhand
			place_blueprint_offhand.global_transform = target_place_transform_offhand
			pass


func _unhandled_input(event: InputEvent) -> void:
	# Handle mousewheel for place distance adjustment when in PLACE state
	if (throw_state_mainhand == ThrowState.PLACE or throw_state_offhand == ThrowState.PLACE):
		if event.is_action_pressed(&"itm|next_hotbar_item"):
			_handle_mousewheel_distance_adjustment(1)  # Increase distance
			get_viewport().set_input_as_handled()  # Prevent hotbar switching
			return
		elif event.is_action_pressed(&"itm|previous_hotbar_item"):
			_handle_mousewheel_distance_adjustment(-1)  # Decrease distance
			get_viewport().set_input_as_handled()  # Prevent hotbar switching
			return

	if event.is_action_pressed(&"playerhand|mainhand_throw"):
		mainhand_item = player.inventory.get_mainhand_item()
		if is_instance_valid(mainhand_item):
			throw_held_timer_mainhand = 0.0
			throw_state_mainhand = ThrowState.THROW
			# Reset mousewheel mode when starting new throw
			mousewheel_mode_mainhand = false
			locked_distance_mainhand = 0.0
	elif event.is_action_released(&"playerhand|mainhand_throw"):
		match throw_state_mainhand:
			ThrowState.THROW:
				player_controller.throw_object(player.inventory.get_mainhand_item())
			ThrowState.PLACE:
				player_controller.place_object(player.inventory.get_mainhand_item(), target_place_transform_mainhand)
		throw_state_mainhand = ThrowState.NONE
		# Reset mousewheel mode when ending throw
		mousewheel_mode_mainhand = false
		locked_distance_mainhand = 0.0

	if event.is_action_pressed(&"playerhand|offhand_throw"):
		offhand_item = player.inventory.get_offhand_item()
		if is_instance_valid(offhand_item):
			throw_held_timer_offhand = 0.0
			throw_state_offhand = ThrowState.THROW
			# Reset mousewheel mode when starting new throw
			mousewheel_mode_offhand = false
			locked_distance_offhand = 0.0
	elif event.is_action_released(&"playerhand|offhand_throw"):
		match throw_state_offhand:
			ThrowState.THROW:
				player_controller.throw_object(player.inventory.get_offhand_item())
			ThrowState.PLACE:
				player_controller.place_object(player.inventory.get_offhand_item(), target_place_transform_offhand)
		throw_state_offhand = ThrowState.NONE
		# Reset mousewheel mode when ending throw
		mousewheel_mode_offhand = false
		locked_distance_offhand = 0.0


func _get_place_transform(object : RigidBody3D, is_mainhand: bool = true) -> Transform3D:
	var from_transform := place_origin.global_transform

	# Check if we're in mousewheel mode for this hand
	var in_mousewheel_mode = mousewheel_mode_mainhand if is_mainhand else mousewheel_mode_offhand
	var locked_distance = locked_distance_mainhand if is_mainhand else locked_distance_offhand

	if in_mousewheel_mode:
		# Use fixed distance (like grab system)
		var move_dir : Vector3 = -player_controller.main_camera.global_basis.z * locked_distance
		print("PLACE DEBUG - Using mousewheel mode, distance: ", locked_distance, " for ", ("mainhand" if is_mainhand else "offhand"))
		return from_transform.translated(move_dir)
	else:
		# Use collision-based placement (original system)
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


func _handle_mousewheel_distance_adjustment(direction: int) -> void:
	# Determine which hand is in PLACE state
	var is_mainhand_placing = (throw_state_mainhand == ThrowState.PLACE)
	var is_offhand_placing = (throw_state_offhand == ThrowState.PLACE)

	if is_mainhand_placing:
		if not mousewheel_mode_mainhand:
			# First mousewheel input - lock in current distance
			var current_distance = _get_current_collision_distance(player.inventory.get_mainhand_item())
			locked_distance_mainhand = _round_to_nearest_increment(current_distance)
			mousewheel_mode_mainhand = true
			print("PLACE DEBUG - Mainhand locked distance at: ", locked_distance_mainhand)

		# Adjust distance
		locked_distance_mainhand = clamp(
			locked_distance_mainhand + (direction * place_distance_increment),
			place_distance_min,
			place_distance_max
		)
		print("PLACE DEBUG - Mainhand distance adjusted to: ", locked_distance_mainhand)

	if is_offhand_placing:
		if not mousewheel_mode_offhand:
			# First mousewheel input - lock in current distance
			var current_distance = _get_current_collision_distance(player.inventory.get_offhand_item())
			locked_distance_offhand = _round_to_nearest_increment(current_distance)
			mousewheel_mode_offhand = true
			print("PLACE DEBUG - Offhand locked distance at: ", locked_distance_offhand)

		# Adjust distance
		locked_distance_offhand = clamp(
			locked_distance_offhand + (direction * place_distance_increment),
			place_distance_min,
			place_distance_max
		)
		print("PLACE DEBUG - Offhand distance adjusted to: ", locked_distance_offhand)


func _get_current_collision_distance(object: RigidBody3D) -> float:
	"""Get the current distance the object would be placed at using collision detection"""
	if not is_instance_valid(object):
		return place_distance

	var from_transform := place_origin.global_transform
	var move_dir : Vector3 = -player_controller.main_camera.global_basis.z * place_distance
	if object.test_move(from_transform, move_dir * place_distance, _collision):
		return _collision.get_travel().length()
	else:
		return place_distance


func _round_to_nearest_increment(distance: float) -> float:
	"""Round distance to nearest increment within min/max bounds"""
	var clamped_distance = clamp(distance, place_distance_min, place_distance_max)
	return round(clamped_distance / place_distance_increment) * place_distance_increment


func _on_inventory_changed() -> void:
	if throw_state_mainhand != ThrowState.NONE:
		if player.inventory.get_mainhand_item() != mainhand_item:
			mainhand_item = null
			throw_state_mainhand = ThrowState.NONE
			# Reset mousewheel mode when inventory changes
			mousewheel_mode_mainhand = false
			locked_distance_mainhand = 0.0
	if throw_state_offhand != ThrowState.NONE:
		if player.inventory.get_offhand_item() != offhand_item:
			offhand_item = null
			throw_state_offhand = ThrowState.NONE
			# Reset mousewheel mode when inventory changes
			mousewheel_mode_offhand = false
			locked_distance_offhand = 0.0
