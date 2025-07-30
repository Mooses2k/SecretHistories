extends Node

enum InteractState {
	NONE,
	PENDING,
	GRAB,
	ADS
}
@export var inventory : Inventory

@onready var interaction_cast: RayCast3D = $"../../ModelRoot/MainCamera/InteractionCast"
@onready var grab_cast: RayCast3D = $"../../ModelRoot/MainCamera/GrabCast"
@onready var player_controller: PlayerController = $".."
@onready var near_cast: Area3D = $"../../ModelRoot/MainCamera/NearCast"

# Releasing the interact key before this time will cause an interaction, holding
# it longer will attempt a grab
@export var interact_threshold : float = 0.2

# Damping parameters for non-heavy grabbed objects
@export var light_object_mass_threshold : float = 20.0  # kg - objects below this get damping
@export var linear_damping_factor : float = 8.0
@export var rotational_damping_factor : float = 8.0
@export var mass_damping_scale : float = 0.8  # How much mass affects damping (0.0-1.0)

var _interaction_held_timer : float = 0.0
var _holding_interact : bool = false

var interact_state : InteractState = InteractState.NONE

var grabbed_item : RigidBody3D = null
# Where the object was grabbed, relative to the object
var grab_position_object : Vector3
# Where the object was grabbed, relative to the raycast
var grab_position_raycast : Vector3

var interact_target : Interactable = null
var grab_target : RigidBody3D = null
var pick_target : PickableItem = null

func _process(delta: float) -> void:
	interaction_cast.force_raycast_update()
	interact_target = interaction_cast.get_collider() as Interactable
	grab_cast.force_raycast_update()
	grab_target = grab_cast.get_collider() as RigidBody3D
	pick_target = grab_cast.get_collider() as PickableItem
	#TODO: move this code to the gui instead, and make near cast behave like kick
	GameManager.game.ui_root.hud_root.active_indicator = HUD.Indicator.NONE
	
	if pick_target:
		GameManager.game.ui_root.hud_root.active_indicator = HUD.Indicator.GRAB
	elif grab_target or interact_target:
		GameManager.game.ui_root.hud_root.active_indicator = HUD.Indicator.DOT
		if is_instance_valid(interact_target) and interact_target.is_in_group(&"IGNITE"):
			GameManager.game.ui_root.hud_root.active_indicator = HUD.Indicator.IGNITE
			print("Fire")
	if GameManager.game.ui_root.hud_root.active_indicator == HUD.Indicator.NONE:
		for body in near_cast.get_overlapping_bodies():
			if body is RigidBody3D:
				GameManager.game.ui_root.hud_root.active_indicator = HUD.Indicator.DOT
				break
	if GameManager.game.ui_root.hud_root.active_indicator == HUD.Indicator.NONE:
		for area in near_cast.get_overlapping_areas():
			if area is Interactable:
				GameManager.game.ui_root.hud_root.active_indicator = HUD.Indicator.DOT
				break
	
	if interact_state == InteractState.PENDING:
		_interaction_held_timer += delta
		if _interaction_held_timer > interact_threshold and grabbed_item == null:
			if not _try_grab():
				player_controller.set_ads(true)
				interact_state = InteractState.ADS
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"player|interact"):
		if not (interact_target or grab_target or pick_target):
			interact_state = InteractState.ADS
			player_controller.set_ads(true)
		else:
			interact_state = InteractState.PENDING
			_interaction_held_timer = 0.0
	elif event.is_action_released(&"player|interact"):
		match interact_state:
			InteractState.ADS:
				player_controller.set_ads(false)
			InteractState.GRAB:
				_reset_object_damping(grabbed_item)
				grabbed_item = null
				player_controller.set_drag_speed_modifier(1.0)
			InteractState.PENDING:
				if pick_target:
					pick_item()
				else:
					interact()
		interact_state = InteractState.NONE
		_holding_interact = false
	elif (
		event.is_action_pressed(&"playerhand|mainhand_throw")
		or event.is_action_pressed(&"playerhand|offhand_throw")
	):
		if interact_state == InteractState.GRAB:
			interact_state = InteractState.NONE
			var item_to_throw = grabbed_item
			_reset_object_damping(item_to_throw)
			grabbed_item = null
			player_controller.set_drag_speed_modifier(1.0)
			player_controller.throw_object(item_to_throw)
			get_viewport().set_input_as_handled()

func _try_grab() -> bool:
	if is_instance_valid(grab_target):
		print("grab")
		grabbed_item = grab_target
		grab_position_object = grabbed_item.to_local(grab_cast.get_collision_point())
		grab_position_raycast = grab_cast.to_local(grab_cast.get_collision_point())
		interact_state = InteractState.GRAB
		return true
	return false
	pass

func _physics_process(delta: float) -> void:
	if is_instance_valid(grabbed_item):
		var point_object := grabbed_item.to_global(grab_position_object)
		var point_raycast := grab_cast.to_global(grab_position_raycast)
		var difference := point_raycast - point_object
		
		# Calculate mass-based force scaling
		var mass = grabbed_item.mass
		var base_force_multiplier = 100.0
		var temp_mass_threshold = light_object_mass_threshold
		var max_force_limit = 220.0
		
		# Scale force based on mass for heavy objects
		var force_multiplier = base_force_multiplier
		if mass > temp_mass_threshold:
			# Increase force multiplier for heavy objects
			var mass_factor = 1.0 + (mass - temp_mass_threshold) / temp_mass_threshold
			force_multiplier = base_force_multiplier * mass_factor * 1.5  # Additional boost for heavy objects
			max_force_limit = 220.0 + (mass - temp_mass_threshold) * 4.0  # Higher limit for heavy objects
		
		var force = (difference * mass * force_multiplier)
		force = force.limit_length(max_force_limit)
		
		grabbed_item.apply_force(force, point_object - grabbed_item.global_position)
		
		# Apply movement speed reduction based on mass
		var speed_reduction_factor = 1.0
		if mass > temp_mass_threshold:
			# Calculate speed reduction: heavier objects = more reduction
			var mass_ratio = mass / 100.0  # Normalize against 100kg reference
			speed_reduction_factor = clamp(1.0 - mass_ratio * 0.6, 0.2, 1.0)  # Min 20% speed
			speed_reduction_factor = max(speed_reduction_factor, 0.2)  # Ensure minimum 20% speed
		
		# Apply speed reduction to player controller
		player_controller.set_drag_speed_modifier(speed_reduction_factor)
		
		# Apply damping to non-heavy objects
		if mass <= light_object_mass_threshold:
			# Calculate mass-scaled damping (lighter objects get more damping)
			var mass_factor = clamp(mass / light_object_mass_threshold, 0.01, 1.0)
			var scaled_linear_damp = linear_damping_factor * (1.0 - mass_factor * mass_damping_scale)
			var scaled_rotational_damp = rotational_damping_factor * (1.0 - mass_factor * mass_damping_scale)
			
			# Ensure minimum damping values
			scaled_linear_damp = max(scaled_linear_damp, 0.01)
			scaled_rotational_damp = max(scaled_rotational_damp, 0.01)
			
			# Apply damping
			grabbed_item.linear_damp = scaled_linear_damp
			grabbed_item.angular_damp = scaled_rotational_damp
		
	elif interact_state == InteractState.GRAB:
		interact_state = InteractState.NONE
		# Reset movement speed when not dragging
		player_controller.set_drag_speed_modifier(1.0)
	
	# Safety check: if grabbed_item becomes invalid, reset drag speed modifier
	if not is_instance_valid(grabbed_item) and interact_state != InteractState.GRAB:
		player_controller.set_drag_speed_modifier(1.0)

func pick_item() -> void:
	if is_instance_valid(pick_target):
		print("pick")
		inventory.add_item(pick_target)

func interact() -> void:
	if is_instance_valid(interact_target):
		print("interact")
		interact_target.interact(owner)

# Helper function to reset object damping when released
func _reset_object_damping(item: RigidBody3D) -> void:
	if is_instance_valid(item):
		# Reset to default physics values (or whatever the object's original values were)
		item.linear_damp = 0.0  # Default Godot linear damping
		item.angular_damp = 0.0  # Default Godot angular damping
