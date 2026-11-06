@tool
class_name PickableItem
extends RigidBody3D
### This is a tool script to support use in player_animations_test.gd

# Cooldown before being able to cause impact damage to the same entity again
const IMPACT_DAMAGE_REPEAT_COOLDOWN : float = 0.25

# World-integrity guard threshold (FALLEN_ITEM_DELETE_Y): every floor level
# sits at y=0 (WorldData's cell grid is flat and items rest around y=1), and
# the deepest legitimate geometry below a slab is the staircase shaft a few
# meters down. Anything below -50 is through-the-world and unreachable, by a
# wide margin (owner ruling: -50 fine for now; revisit when vazgriz 3D
# dungeons bring very large levels). A free-falling item is clamped to
# max_speed (12 m/s), so it reaches the threshold in seconds.
const FALLEN_ITEM_DELETE_Y : float = -50.0

#const ImpactAudioManager = preload("res://scenes/audio/impact_audio_manager.gd")

signal item_data_changed()
signal item_state_changed(previous_state, current_state)

@export_flags_3d_physics var dropped_layers : int = 0
@export_flags_3d_physics var dropped_mask : int = 0

@export var damage_speed_threshold : float = 1.0
@export var max_speed : float = 12.0
@export var item_drop_sound : AudioStream
@export var item_throw_sound : AudioStream
@export var melee_damage_type : GlobalConsts.AttackTypes = GlobalConsts.AttackTypes.BLUDGEONING

var owner_character : Node = null
var item_state = GlobalConsts.ItemState.DROPPED: set = set_item_state
var noise_level : float = 0   # Noise detectable by characters; is a float for stamina -> noise conversion if nothing else
var item_max_noise_level = 5
var item_sound_level = 10

@export var thrown_point_first : bool   # Some items like swords and spears should be thrown point first
@export var can_spin : bool   # Some items should spin when thrown

# stores the impact damage cooldown for each object that has been hit
# by this item
var impact_damage_cooldown : Dictionary[Node, float]

@onready var audio_player = get_node("DropSound")
@onready var impact_audio_manager : ImpactAudioManager

#onready var mesh_instance = $MeshInstance
@onready var item_drop_sound_flesh : AudioStream = load("res://resources/sounds/impacts/blade_to_flesh/blade_to_flesh.wav")

@onready var placement_position = %PlacementAnchor


func _enter_tree():
	if not audio_player:
		var drop_sound = AudioStreamPlayer3D.new()
		drop_sound.name = "DropSound"
		drop_sound.bus = "Effects"
		add_child(drop_sound)

	# Create and configure the impact audio manager
	impact_audio_manager = ImpactAudioManager.new()
	add_child(impact_audio_manager)
	impact_audio_manager.configure_for_object_type("pickable_item")

	check_item_state()


func _ready():
	# Configure the audio manager after the scene is fully loaded
	# This ensures item_drop_sound is properly set from the editor
	call_deferred("_configure_audio_manager")


func _configure_audio_manager():
	if impact_audio_manager:
		if item_drop_sound:
			impact_audio_manager.drop_sound = item_drop_sound
			impact_audio_manager.max_noise_level = item_max_noise_level


func _process(delta):
	if self.noise_level > 0:
		await get_tree().create_timer(0.2).timeout
		self.noise_level = 0


func _physics_process(delta: float) -> void:
	for node in impact_damage_cooldown.keys():
		var time = impact_damage_cooldown[node]
		time -= delta
		if not is_instance_valid(node) or time <= 0.0:
			impact_damage_cooldown.erase(node)
		else:
			impact_damage_cooldown[node] = time


func check_item_state():
	match self.item_state:
		GlobalConsts.ItemState.DROPPED:
			set_physics_dropped()
		GlobalConsts.ItemState.INVENTORY:
			set_physics_equipped()
		GlobalConsts.ItemState.EQUIPPED:
			set_physics_equipped()


func set_item_state(value : int) :
	var previous = item_state
	item_state = value
	emit_signal("item_state_changed", previous, item_state)


func play_throw_sound():
	if self.item_drop_sound and self.audio_player:
		self.audio_player.stream = self.item_throw_sound
		self.audio_player.volume_db = item_sound_level   # This could be adjusted
		self.audio_player.bus = "Effects"
		self.audio_player.play()
		if self.noise_level < 8:
			self.noise_level = 3


## Method for the audio manager to set noise level
func set_noise_level(level: float):
	noise_level = level


func set_physics_dropped():
	self.collision_layer = dropped_layers
	self.collision_mask = dropped_mask
	self.freeze = false


func set_physics_equipped():
	self.collision_layer = 0
	self.collision_mask = 0
	self.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	self.freeze = true


func can_damage() -> bool:
	return (
		linear_velocity.length() >= damage_speed_threshold and
		item_state == GlobalConsts.ItemState.DROPPED
	)


func get_impact_damage() -> int:
	if not can_damage(): return 0
	var result = melee_throw_damage()
	if result < 0:
		result = max(int(linear_velocity.length() * mass * 0.5), 1)
	return result


# Override in melee.gd
# If the return is negative, a default velocity based calculation will be
# used instead
func melee_throw_damage() -> int:
	return -1


# used to decelerate objects on impact with hurtboxes
func decelerate_item_velocity() -> void:
	var inertia_factor = min(mass / 4.0, 1.0)
	linear_velocity = lerp(Vector3.ZERO, linear_velocity, inertia_factor)


func _integrate_forces(state):
	# Handle impact detection for sound using the audio manager
	if impact_audio_manager and (item_state == GlobalConsts.ItemState.DROPPED):
		impact_audio_manager.process_impact_detection(state)

	# Handle velocity clamping
	if item_state == GlobalConsts.ItemState.DROPPED:
		state.linear_velocity = state.linear_velocity.limit_length(max_speed)

		# World-integrity guard: an item that fell through the world can never
		# be reached again, so remove it instead of leaking a falling body.
		# Only DROPPED bodies run here (equipped ones are frozen), the check
		# is one float compare per physics tick, and ShardOfTheComet is never
		# deleted. The shard is matched by script global name (same idiom as
		# anchor_spawner.gd); a class reference here would be a compile cycle
		# PickableItem -> ShardOfTheComet -> EquipmentItem -> PickableItem.
		var script_global_name := ""
		if get_script():
			script_global_name = get_script().get_global_name()
		if global_position.y < FALLEN_ITEM_DELETE_Y and script_global_name != "ShardOfTheComet":
			# Only items that are actually inside the scene tree may be
			# deleted. Cached floor instances (FloorLevelHandler keeps them
			# out of world_root) keep their DROPPED items for revisit, but
			# during a floor transition those bodies still run
			# _integrate_forces with no floor colliders beneath, so without
			# this check the guard silently looted cached floors.
			if not is_inside_tree():
				return
			push_warning("World-integrity: removing item '%s' that fell below the world (y=%0.1f)" % [name, global_position.y])
			queue_free()


func on_hurtbox_hit(hurtbox : Hurtbox) -> void:
	if impact_damage_cooldown.has(hurtbox.owner_node): return
	var damage = get_impact_damage()
	if damage > 0:
		hurtbox.damage(damage, melee_damage_type, linear_velocity.normalized(), global_position)
		decelerate_item_velocity()
		impact_damage_cooldown[hurtbox.owner_node] = IMPACT_DAMAGE_REPEAT_COOLDOWN
