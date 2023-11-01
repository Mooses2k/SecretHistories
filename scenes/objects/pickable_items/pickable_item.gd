tool
class_name PickableItem
extends RigidBody


signal item_state_changed(previous_state, current_state)

export(int, LAYERS_3D_PHYSICS) var dropped_layers : int = 0
export(int, LAYERS_3D_PHYSICS) var dropped_mask : int = 0
export(int, LAYERS_3D_PHYSICS) var damage_mask : int = 0
export(int, "Rigid", "Static", "Character", "Kinematic") var dropped_mode : int = MODE_RIGID

export(int, LAYERS_3D_PHYSICS) var equipped_layers : int = 0
export(int, LAYERS_3D_PHYSICS) var equipped_mask : int = 0
export(int, "Rigid", "Static", "Character", "Kinematic") var equipped_mode : int = MODE_KINEMATIC

export var max_speed : float = 12.0
export var item_drop_sound : AudioStream
export var item_throw_sound : AudioStream
export(AttackTypes.Types) var melee_damage_type : int = 0

onready var audio_player = get_node("DropSound")

#onready var mesh_instance = $MeshInstance
var owner_character : Node = null
var item_state = GlobalConsts.ItemState.DROPPED setget set_item_state
var noise_level : float = 0   # Noise detectable by characters; is a float for stamina -> noise conversion if nothing else
var item_max_noise_level = 5
var item_sound_level = 10

var can_throw_damage : bool
var has_thrown = false
var is_higher_damage = false
#var deceleration_factor = 0.9
var initial_linear_velocity


func _enter_tree():
	if not audio_player:
		var drop_sound = AudioStreamPlayer3D.new()
		drop_sound.name = "DropSound"
		drop_sound.bus = "Effects"
		add_child(drop_sound)
	
	check_item_state()


func _process(delta):
	if self.noise_level > 0:
		yield(get_tree().create_timer(0.2), "timeout")
		self.noise_level = 0


func check_item_state():
	match self.item_state:
		GlobalConsts.ItemState.DROPPED:
			set_physics_dropped()
		GlobalConsts.ItemState.INVENTORY:
			set_physics_equipped()
		GlobalConsts.ItemState.EQUIPPED:
			set_physics_equipped()
		GlobalConsts.ItemState.DAMAGING:
			set_item_damaging()


func set_item_state(value : int) :
	var previous = item_state
	item_state = value
	emit_signal("item_state_changed", previous, item_state)


func play_throw_sound():
	if self.item_drop_sound and self.audio_player:
		self.audio_player.stream = self.item_throw_sound
		self.audio_player.unit_db = item_sound_level   # This could be adjusted
		self.audio_player.bus = "Effects"
		self.audio_player.play()
		self.noise_level = 3


func play_drop_sound(body):
	if self.item_drop_sound and self.audio_player:
		self.audio_player.stream = self.item_drop_sound
		self.audio_player.unit_db = item_sound_level   # This should eventually be based on speed
		self.audio_player.bus = "Effects"
		self.audio_player.play()
		self.noise_level = item_max_noise_level   # This should eventually be based on speed


func set_physics_dropped():
	self.collision_layer = dropped_layers
	self.collision_mask = dropped_mask
	self.mode = dropped_mode


func set_item_damaging():
	self.collision_layer = dropped_layers
	self.collision_mask = damage_mask
	print("Line 141 pickable_item.gd self's collision_mask: ", self.collision_mask)
	self.mode = dropped_mode


func set_physics_equipped():
	self.collision_layer = equipped_layers
	self.collision_mask = equipped_mask
	self.mode = equipped_mode


func _integrate_forces(state):
	if item_state == GlobalConsts.ItemState.DROPPED:
		state.linear_velocity = state.linear_velocity.normalized() * min(state.linear_velocity.length(), max_speed)
	if item_state == GlobalConsts.ItemState.DAMAGING:
		state.linear_velocity = state.linear_velocity.normalized() * min(state.linear_velocity.length(), max_speed)
