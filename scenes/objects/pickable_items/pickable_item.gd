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
export var item_drop_sound_flesh : AudioStream
export var item_throw_sound : AudioStream
export(AttackTypes.Types) var melee_damage_type : int = 0

onready var audio_player = get_node("DropSound")

#onready var mesh_instance = $MeshInstance
var owner_character : Node = null
var item_state = GlobalConsts.ItemState.DROPPED setget set_item_state
var noise_level : float = 0   # Noise detectable by characters; is a float for stamina -> noise conversion if nothing else
var item_max_noise_level = 5
var item_sound_level = 10
var item_drop_sound_level = 10
var item_drop_pitch_level = 10

var can_throw_damage : bool
var has_thrown = false
var is_higher_damage = false
#var deceleration_factor = 0.9
var initial_linear_velocity
var is_soundplayer_ready = false


func _enter_tree():
	if not audio_player:
		var drop_sound = AudioStreamPlayer3D.new()
		drop_sound.name = "DropSound"
		drop_sound.bus = "Effects"
		add_child(drop_sound)
	
	match self.item_state:
		GlobalConsts.ItemState.DROPPED:
			set_physics_dropped()
		GlobalConsts.ItemState.INVENTORY:
			set_physics_equipped()
		GlobalConsts.ItemState.EQUIPPED:
			set_physics_equipped()
		GlobalConsts.ItemState.DAMAGING:
			set_weapon_damaging()
	
	is_soundplayer_ready = true


func _process(delta):
	if self.noise_level > 0:
		yield(get_tree().create_timer(0.2), "timeout")
		self.noise_level = 0


# TODO: Performance issue, should be on collision, not every physics frame
func _physics_process(delta):
	throw_damage(delta)


# Damage mask has had Player removed to avoid walking over items bugs - TODO: later should be no damage mode, probably just based on momentum
func throw_damage(delta):
	if can_throw_damage:
		
		var bodies = get_colliding_bodies()
		if has_thrown == false:
			initial_linear_velocity = linear_velocity.z
			has_thrown = true
		
		for body_found in bodies:
			if body_found.is_in_group("CHARACTER"):
				var item_damage = int(abs(initial_linear_velocity)) * mass
				if not is_higher_damage :
					if item_damage > 5:
						item_damage = 2
				print("Damage inflicted on: ", body_found.name, " is: ", item_damage)
				body_found.damage(item_damage, melee_damage_type, body_found)
				can_throw_damage = false
				has_thrown = false
				decelerate_item_velocity(delta, true)
				item_state = GlobalConsts.ItemState.DROPPED
			else:
				has_thrown = false
				can_throw_damage = false
#				decelerate_item_velocity(delta, true)   # Causes glitches like thrown objects sticking in arched wall collisions
				item_state = GlobalConsts.ItemState.DROPPED


func decelerate_item_velocity(delta, decelerate):
	if self.item_size:
		if self.item_size == GlobalConsts.ItemSize.SIZE_SMALL:
			if decelerate == true:
				print("decelerating item")
				linear_velocity *= 0


func set_item_state(value : int) :
	var previous = item_state
	item_state = value
	emit_signal("item_state_changed", previous, item_state)


func implement_throw_damage(higher_damage):
	is_higher_damage = higher_damage
	can_throw_damage = true
	play_throw_sound()


func play_throw_sound():
	if self.item_drop_sound and self.audio_player:
		self.audio_player.stream = self.item_throw_sound
		self.audio_player.unit_db = item_sound_level   # This could be adjusted
		self.audio_player.bus = "Effects"
		self.audio_player.play()
		self.noise_level = 3


func play_drop_sound(body):
	if self.item_drop_sound and self.audio_player and self.linear_velocity.length() > 0.2 and self.is_soundplayer_ready:
		self.audio_player.stream = self.item_drop_sound
		print(str(self.name) + " velo = " + str(self.linear_velocity.length()))
		if "Cultist" in body.name and self.item_drop_sound_flesh:
			self.audio_player.stream = self.item_drop_sound_flesh

		if self.get("primary_damage1"):
			self.item_drop_sound_level = self.linear_velocity.length() * 5.0
			self.item_drop_pitch_level = self.linear_velocity.length() * 0.2
		else:
			self.item_drop_sound_level = self.linear_velocity.length() * 2.0
			self.item_drop_pitch_level = self.linear_velocity.length() * 0.4
			
		self.audio_player.unit_db = clamp(self.item_drop_sound_level, 5.0, 20.0)   # This should eventually be based on speed
		self.audio_player.pitch_scale = clamp(self.item_drop_pitch_level, 0.85, 1.0)
		self.audio_player.bus = "Effects"
		self.audio_player.play()
		self.noise_level = item_max_noise_level   # This should eventually be based on speed\
		self.is_soundplayer_ready = false
		start_delay()


func start_delay():
	yield(get_tree().create_timer(0.2), "timeout")
	self.is_soundplayer_ready = true


func set_physics_dropped():
	self.collision_layer = dropped_layers
	self.collision_mask = dropped_mask
	self.mode = dropped_mode


func set_weapon_damaging():
	self.collision_layer = dropped_layers
	self.collision_mask = damage_mask
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
