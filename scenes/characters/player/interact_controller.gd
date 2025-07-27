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
				grabbed_item = null
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
			grabbed_item = null
			player_controller.throw_object(grabbed_item)
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
		var force = (difference * grabbed_item.mass * 50.0).limit_length(300.0)
		grabbed_item.apply_force(force, point_object - grabbed_item.global_position)
	elif interact_state == InteractState.GRAB:
		interact_state = InteractState.NONE

func pick_item() -> void:
	if is_instance_valid(pick_target):
		print("pick")
		inventory.add_item(pick_target)

func interact() -> void:
	if is_instance_valid(interact_target):
		print("interact")
		interact_target.interact(owner)
