@tool
class_name PickableItem
extends RigidBody3D

### Is a tool to support use in player_animations_test.gd


signal item_state_changed(previous_state, current_state)

@export var dropped_layers : int = 0 # (int, LAYERS_3D_PHYSICS)
@export var dropped_mask : int = 0 # (int, LAYERS_3D_PHYSICS)
@export var damage_mask : int = 0 # (int, LAYERS_3D_PHYSICS)

@export var max_speed : float = 12.0
@export var item_drop_sound : AudioStream
@export var item_throw_sound : AudioStream
@export var melee_damage_type : int = 0 # (AttackTypes.Types)

var owner_character : Node = null
var item_state = GlobalConsts.ItemState.DROPPED: set = set_item_state
var noise_level : float = 0   # Noise detectable by characters; is a float for stamina -> noise conversion if nothing else
var item_max_noise_level = 5
var item_sound_level = 10
var item_drop_sound_level = 10
var item_drop_pitch_level = 10

@export var thrown_point_first : bool   # Some items like swords and spears should be thrown point first
@export var can_spin : bool   # Some items should spin when thrown

var has_thrown = false
#var deceleration_factor = 0.9

var initial_linear_velocity
var is_soundplayer_ready = false

@onready var audio_player = get_node("DropSound")

#onready var mesh_instance = $MeshInstance
@onready var item_drop_sound_flesh : AudioStream = load("res://resources/sounds/impacts/blade_to_flesh/blade_to_flesh.wav")

@onready var placement_position = %PlacementAnchor


func _enter_tree():
	if not audio_player:
		var drop_sound = AudioStreamPlayer3D.new()
		drop_sound.name = "DropSound"
		drop_sound.bus = "Effects"
		add_child(drop_sound)
	
	check_item_state()
	is_soundplayer_ready = true


func _process(delta):
	if self.noise_level > 0:
		await get_tree().create_timer(0.2).timeout
		self.noise_level = 0


func _physics_process(delta):
	if !sleeping:
		if !is_instance_valid(owner_character):   # this is still hacky, but don't do throw damage if grabbing, basically
			throw_damage(delta)


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
		self.audio_player.volume_db = item_sound_level   # This could be adjusted
		self.audio_player.bus = "Effects"
		self.audio_player.play()
		self.noise_level = 3


func play_drop_sound(body):
	if !is_instance_valid(LoadScene.loadscreen):   # If it's at least a few seconds after level load
		if self.item_drop_sound and self.audio_player and self.linear_velocity.length() > 0.2 and self.is_soundplayer_ready:
			self.audio_player.stream = self.item_drop_sound
			
			if "Cultist" in body.name:
				self.audio_player.stream = self.item_drop_sound_flesh
				
				if self.get("primary_damage1"): 
					# Drop sound volume depends on item damage when cultist is the collided body
					if self.get("can_spin"):   # If item can spin (cutting attack), use secondary damage
						self.item_drop_sound_level = self.linear_velocity.length() * 0.4 * (self.secondary_damage1 + self.secondary_damage2)
						self.item_drop_pitch_level = self.linear_velocity.length() * 0.02 * (self.secondary_damage1 + self.secondary_damage2)
					else:   # If item cannot spin (thrown point first / thrust attack), use primary damage
						self.item_drop_sound_level = self.linear_velocity.length() * 0.4 * (self.primary_damage1 + self.primary_damage2)
						self.item_drop_pitch_level = self.linear_velocity.length() * 0.02 * (self.primary_damage1 + self.primary_damage2)
				else:
					self.item_drop_sound_level = self.linear_velocity.length() * 0.05
					self.item_drop_pitch_level = self.linear_velocity.length() * 0.4
			else:
				self.item_drop_sound_level = self.linear_velocity.length() * 5.0
				self.item_drop_pitch_level = self.linear_velocity.length() * 0.4
				
			self.audio_player.volume_db = clamp(self.item_drop_sound_level, 5.0, 20.0)  
			self.audio_player.pitch_scale = clamp(self.item_drop_pitch_level, 0.85, 1.0)
			self.audio_player.bus = "Effects"
			self.audio_player.play()
			self.noise_level = clamp((self.item_max_noise_level * self.linear_velocity.length()), 1.0, 5.0)
			print("noise_level == " + str(self.noise_level))
			self.is_soundplayer_ready = false
			start_delay()


func start_delay():
	if self.is_inside_tree():
		await get_tree().create_timer(0.2).timeout
		self.is_soundplayer_ready = true


func set_physics_dropped():
	self.collision_layer = dropped_layers
	self.collision_mask = dropped_mask
	self.freeze = false


func set_item_damaging():
	self.collision_layer = dropped_layers
	self.collision_mask = damage_mask
	print("Line 141 pickable_item.gd self's collision_mask: ", self.collision_mask)
	self.freeze = false


func set_physics_equipped():
	self.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	self.freeze = true


func throw_damage(delta):
	if item_state == GlobalConsts.ItemState.DAMAGING:
		var bodies = get_colliding_bodies()
		if has_thrown == false:
			initial_linear_velocity = linear_velocity.z
			has_thrown = true
		
		for body_found in bodies:
			if body_found.is_in_group("CHARACTER"):
				var item_damage_by_momentum = int(abs(initial_linear_velocity)) * mass * 0.3
				var item_damage = 1
				
				# TODO: deal with can_spin items that aren't melee items like torch
				if can_spin or thrown_point_first:
					item_damage = melee_throw_damage()
					print(item_damage, " damage calculated in pickable_item")
				else:
					print("Item thrown is NOT a melee item")
					item_damage = item_damage_by_momentum
					print(item_damage, " damage calculated")
				
				# Handle bad case (like torches apparently)
				if item_damage == null:
					item_damage = 1
				
				print("Damage inflicted on: ", body_found.name, " is: ", item_damage)
				body_found.damage(item_damage, melee_damage_type, body_found)
				has_thrown = false
				decelerate_item_velocity(delta, true)
				set_item_state(GlobalConsts.ItemState.DROPPED)
			else:
				has_thrown = false
#				decelerate_item_velocity(delta, true)   # Causes glitches like thrown objects sticking in arched wall collisions
				set_item_state(GlobalConsts.ItemState.DROPPED)


func melee_throw_damage():   # Override in melee.gd
	pass


func decelerate_item_velocity(delta, decelerate):
	if is_in_group("TINY_ITEM"):
		if self.item_size == GlobalConsts.ItemSize.SIZE_SMALL:
			if decelerate == true:
				print("decelerating item")
				linear_velocity *= 0


func _integrate_forces(state):
	if item_state == GlobalConsts.ItemState.DROPPED:
		state.linear_velocity = state.linear_velocity.normalized() * min(state.linear_velocity.length(), max_speed)
	if item_state == GlobalConsts.ItemState.DAMAGING:
		state.linear_velocity = state.linear_velocity.normalized() * min(state.linear_velocity.length(), max_speed)
