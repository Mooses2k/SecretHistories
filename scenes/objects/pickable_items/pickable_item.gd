@tool
class_name PickableItem
extends RigidBody3D

### This is a tool script to support use in player_animations_test.gd


signal item_data_changed()
signal item_state_changed(previous_state, current_state)

@export_flags_3d_physics var dropped_layers : int = 0 # (int, LAYERS_3D_PHYSICS)
@export_flags_3d_physics var dropped_mask : int = 0 # (int, LAYERS_3D_PHYSICS)
@export_flags_3d_physics var damage_mask : int = 0 # (int, LAYERS_3D_PHYSICS)

@export var max_speed : float = 12.0
@export var item_drop_sound : AudioStream
@export var item_throw_sound : AudioStream
@export var melee_damage_type : int = 0 # (GlobalConsts.AttackTypes)

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

var initial_linear_velocity
var is_soundplayer_ready = false
var old_contact_count = 0
var impact_impulse_threshold : float = mass/18.0  ## Minimum impulse magnitude to trigger sound
var old_velocity : float = 0.0  ## Track previous velocity for change detection
var velocity_change_threshold : float = 0.1  ## Minimum velocity change to trigger sound (lower for lighter objects)
var cooldown_time : float = 0.05  ## Time between allowed collision sounds

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
		if self.noise_level < 8:
			self.noise_level = 3


func play_drop_sound(impact_intensity: float):
	if (!LoadScene.loading):
		if self.item_drop_sound and self.audio_player and self.is_soundplayer_ready:
			print("DEBUG: if drop sound and audio_player and is_soundplayer_ready")
			self.audio_player.stream = self.item_drop_sound
			
			# Scale volume based on impact intensity (0-5 range for lighter objects mapped to -25 to +10 dB)
			var volume_scale = (impact_intensity / 5.0)  # Normalize to 0-1 for lighter objects
			self.audio_player.volume_db = lerp(-25.0, 10.0, volume_scale)
			
			# Scale pitch based on impact intensity (0-5 range mapped to 0.7 to 1.6)
			# Higher impact = higher pitch (faster sound)
			var pitch_scale = lerp(0.7, 1.6, volume_scale)
			self.audio_player.pitch_scale = pitch_scale
			
			self.audio_player.bus = "Effects"
			self.audio_player.play()
			
			print("DEBUG: Impact intensity:", impact_intensity)
			print("DEBUG: Final volume_db:", self.audio_player.volume_db)
			print("DEBUG: Final pitch_scale:", self.audio_player.pitch_scale)
			print("DEBUG: audio_player.playing = ", audio_player.playing)
			
			self.noise_level = clamp((self.item_max_noise_level * impact_intensity), 1.0, 5.0)
			#print("DEBUG: thrown item noise_level == " + str(self.noise_level))
			self.is_soundplayer_ready = false
			start_delay()


func start_delay():
	var timer = get_tree().create_timer(cooldown_time)
	timer.timeout.connect(_on_delay_finished)


func _on_delay_finished():
	prints("DELAY DEBUG - Resetting is_soundplayer_ready to true")
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
	self.collision_layer = 0
	self.collision_mask = 0
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
				var item_damage_by_momentum = int(abs(initial_linear_velocity)) * mass * 0.5
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
				body_found.damage(item_damage, melee_damage_type)
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
	# Handle impact detection for sound
	if !LoadScene.loading and (item_state == GlobalConsts.ItemState.DROPPED or item_state == GlobalConsts.ItemState.DAMAGING):
		var current_velocity = state.linear_velocity.length()
		var velocity_change = abs(current_velocity - old_velocity)
		
		# Check all contact points for significant impulses
		var max_impulse_magnitude = 0.0
		var total_impulse = Vector3.ZERO
		
		for i in state.get_contact_count():
			var impulse = state.get_contact_impulse(i)
			var impulse_magnitude = impulse.length()
			
			if impulse_magnitude > max_impulse_magnitude:
				max_impulse_magnitude = impulse_magnitude
			
			total_impulse += impulse
		
		# Play sound if impulse is significant AND there's a sudden velocity change
		# Use lower thresholds for lighter objects
		if (max_impulse_magnitude > impact_impulse_threshold
			and velocity_change > velocity_change_threshold
			and is_soundplayer_ready):
			# Cap impact intensity at 5.0 for lighter objects (vs 10.0 for large objects)
			var impact_intensity = min(max_impulse_magnitude, 5.0)
			play_drop_sound(impact_intensity)
			print("Pickable item impact detected - Max impulse: ", max_impulse_magnitude, " Velocity change: ", velocity_change, " Total impulse: ", total_impulse.length())
		
		old_velocity = current_velocity
	
	old_contact_count = state.get_contact_count()
	
	# Handle velocity clamping
	if item_state == GlobalConsts.ItemState.DROPPED:
		state.linear_velocity = state.linear_velocity.normalized() * min(state.linear_velocity.length(), max_speed)
	if item_state == GlobalConsts.ItemState.DAMAGING:
		state.linear_velocity = state.linear_velocity.normalized() * min(state.linear_velocity.length(), max_speed)
