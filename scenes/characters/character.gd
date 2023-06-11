class_name Character
extends KinematicBody


signal character_died()
signal is_hit(current_health)
signal is_moving(is_player_moving)
signal player_landed()

var _alive : bool = true
var _type_damage_multiplier : PoolByteArray
export(Array, AttackTypes.Types) var immunities : Array
export var max_health : int = 100
onready var current_health : float = self.max_health

export var kick_damage : int

export var move_speed : float = 7.0
export var acceleration : float = 32.0
export var mass : float = 100.0

onready var character_state : CharacterState = CharacterState.new(self)

onready var inventory = $Inventory
onready var mainhand_equipment_root = $"%MainHandEquipmentRoot"
onready var offhand_equipment_root = $"%OffHandEquipmentRoot"
onready var belt_position = $"%BeltPosition"
onready var drop_position_node = $Body/DropPosition
onready var character_body = $Body   # Don't name this just plain 'body' unless you want bugs
onready var skeleton = $"%Skeleton"
onready var collision_shape = $CollisionShape
onready var animation_tree = $AnimationTree
onready var additional_animations  = $AdditionalAnimations

enum ItemSelection {
	ITEM_MAINHAND,
	ITEM_OFFHAND,
}

enum ThrowState {
	IDLE,
	PRESSING,
	SHOULD_PLACE,
	SHOULD_THROW,
}

# For player-heard audio and for sound propogation to other characters' sensors
enum SurfaceType {
	WOOD,
	CARPET,
	STONE,
	WATER,
	GRAVEL,
	METAL, 
	TILE
}

# States from stealth player controller addon
enum State {
	STATE_WALKING,
	STATE_LEANING,
	STATE_CROUCHING,
	STATE_CRAWLING,
	STATE_CLAMBERING_RISE,
	STATE_CLAMBERING_LEDGE,
	STATE_CLAMBERING_VENT,
	STATE_NOCLIP,
}

# Checks if the player is equipping something or not 
enum Animation_state {
	EQUIPPED,
	NOT_EQUIPPED,
}

enum hold_states {
	SMALL_GUN_ITEM,
	LARGE_GUN_ITEM,
	MELEE_ITEM,
	LANTERN_ITEM,
	SMALL_GUN_ADS,
	LARGE_GUNS_ADS,
}

var mainhand_animation = Animation_state.NOT_EQUIPPED
var current_mainhand_item_animation = hold_states.MELEE_ITEM

#const TEXTURE_SOUND_LIB = {
#	"checkerboard" : {
#		"amplifier" : 5.0,
#		"sfx_folder" : "resources/sounds/footsteps/footsteps"
#	}
#}

export var speed : float = 0.5
export var gravity : float = 10.0
export(float, 0.05, 1.0) var crouch_rate = 0.08
export(float, 0.1, 1.0) var crawl_rate = 0.5
export var move_drag : float = 0.2
#export(float, -45.0, -8.0, 1.0) var max_lean = -10.0
export var interact_distance : float = 0.75
export var _legcast : NodePath
export(AttackTypes.Types) var damage_type : int = 0
export (float) var kick_impulse

var state = State.STATE_WALKING

var light_level : float = 0.0

var velocity : Vector3 = Vector3.ZERO
var _current_velocity : Vector3 = Vector3.ZERO

onready var _camera = get_node("FPSCamera")
onready var _collider = get_node("CollisionShape")
onready var _crouch_collider = get_node("CollisionShape2")
onready var _surface_detector = get_node("SurfaceDetector")
onready var _sound_emitter = get_node("SoundEmitter")
onready var _audio_player = get_node("Audio")
onready var _player_hitbox = get_node("CanStandChecker")
onready var _ground_checker = $"%GroundChecker"
onready var legcast : RayCast = get_node(_legcast) as RayCast
onready var _speech_player = get_node("Audio/Speech")

var stamina := 600.0

#var active_mode_index = 0
#onready var active_mode : ControlMode = get_child(0)

var wanna_stand : bool = false
var is_crouching : bool = false
var can_stand : bool = false
var is_player_crouch_toggle : bool = true
var do_crouch : bool = false

var grab_press_length : float = 0.0
var wanna_grab : bool = false
var is_grabbing : bool = false
var interaction_handled : bool = false
var grab_object : RigidBody = null
var grab_relative_object_position : Vector3
var grab_distance : float = 0
var drag_object : RigidBody = null
#var current_object = null

var wants_to_drop = false
var crouch_equipment_target_pos = 0.663
var equipment_orig_pos : float

var clamber_destination : Vector3 = Vector3.ZERO
var _clamber_m = null
var clamber_target
var is_clambering : bool = false
var clamberable_obj # : RigidBody      # commented to allow static bodies too
var is_clamberable # : RigidBody = null   # commented to allow static bodies too

var is_player_moving : bool = false
var is_moving_forward : bool = false
var is_to_move : bool = true
var move_dir = Vector3()
var do_sprint : bool = false

export var jump_force : float = 3.5
var grounded = false
var do_jump : bool = false
var is_jumping : bool = false

var low_kick : bool = false   # Should we do a low kick instead of a stomp kick?

var noise_level : float = 0   # Noise detectable by characters; is a float for stamina -> noise conversion if nothing else

var is_reloading = false


func _ready():
	_type_damage_multiplier.resize(AttackTypes.Types._COUNT)
	for i in _type_damage_multiplier.size():
		_type_damage_multiplier[i] = 1
	for immunity in self.immunities:
		_type_damage_multiplier[immunity] = 0
	
	_clamber_m = ClamberManager.new(self, _camera, get_world())
	equipment_orig_pos = mainhand_equipment_root.transform.origin.y
	
	# TODO: Move all this to character_audio.gd
	# Movement audio	
	_audio_player.load_sounds("resources/sounds/footsteps/stone_footsteps", 3)
	_audio_player.load_sounds("resources/sounds/footsteps/wood_footsteps", 4)
	_audio_player.load_sounds("resources/sounds/footsteps/water_footsteps", 5)
	_audio_player.load_sounds("resources/sounds/footsteps/gravel_footsteps", 6)
	_audio_player.load_sounds("resources/sounds/footsteps/carpet_footsteps", 7)
	_audio_player.load_sounds("resources/sounds/footsteps/metal_footsteps", 8)
	_audio_player.load_sounds("resources/sounds/footsteps/tile_footsteps", 9)
#	_audio_player.load_sounds("resources/sounds/player/sfx/footsteps", 0)
	_audio_player.load_sounds("resources/sounds/breathing/breathe", 1)
	_audio_player.load_sounds("resources/sounds/jumping_landing/landing", 2)
	_audio_player._footstep_sounds = _audio_player._stone_footstep_sounds
		
	# Speech audio - these should eventually be moved to each enemy's script or character audio
	# and the paths adjusted to the correct voice
	_audio_player.load_sounds("resources/sounds/voices/cultists/neophyte/dylanb_vo/idle", 13)
	_audio_player.load_sounds("resources/sounds/voices/cultists/neophyte/dylanb_vo/alert", 14)
	_audio_player.load_sounds("resources/sounds/voices/cultists/neophyte/dylanb_vo/detection", 15)
	_audio_player.load_sounds("resources/sounds/voices/cultists/neophyte/dylanb_vo/ambush", 16)
	_audio_player.load_sounds("resources/sounds/voices/cultists/neophyte/dylanb_vo/chase", 17)
	_audio_player.load_sounds("resources/sounds/voices/cultists/neophyte/dylanb_vo/fight", 18)
	_audio_player.load_sounds("resources/sounds/voices/cultists/neophyte/dylanb_vo/reload", 19)
	_audio_player.load_sounds("resources/sounds/voices/cultists/neophyte/dylanb_vo/flee", 20)
	_audio_player.load_sounds("resources/sounds/voices/cultists/neophyte/dylanb_vo/dialog_q", 21)
	_audio_player.load_sounds("resources/sounds/voices/cultists/neophyte/dylanb_vo/dialog_a", 22)
	_audio_player.load_sounds("resources/sounds/voices/cultists/neophyte/dylanb_vo/dialog_sequence", 23)
	_audio_player.load_sounds("resources/sounds/voices/cultists/neophyte/dylanb_vo/surprised", 24)
	_audio_player.load_sounds("resources/sounds/voices/cultists/neophyte/dylanb_vo/fire", 25)
	_audio_player.load_sounds("resources/sounds/voices/cultists/neophyte/dylanb_vo/snake", 26)
	_audio_player.load_sounds("resources/sounds/voices/cultists/neophyte/dylanb_vo/bomb", 27)


func _physics_process(delta : float):
	check_state_animation(delta)
	check_current_item_animation()
	can_stand = true
	for body in _player_hitbox.get_overlapping_bodies():
		if body is RigidBody:
			can_stand = false
	
	interaction_handled = false
	
	if wanna_stand:
		if _collider.disabled:
			_collider.set_deferred("disabled", false)
			_crouch_collider.set_deferred("disabled", true)
	
		var from = mainhand_equipment_root.transform.origin.y
		mainhand_equipment_root.transform.origin.y = lerp(from, equipment_orig_pos, 0.08)
	
		from = offhand_equipment_root.transform.origin.y
		offhand_equipment_root.transform.origin.y = lerp(from, equipment_orig_pos, 0.08)
		var d1 = mainhand_equipment_root.transform.origin.y - equipment_orig_pos
		if d1 > -0.04:
			mainhand_equipment_root.transform.origin.y = equipment_orig_pos
			offhand_equipment_root.transform.origin.y = equipment_orig_pos
	
	match state:
		State.STATE_WALKING:
			_walk(delta)
	
		State.STATE_CROUCHING:
			if !do_crouch and is_player_crouch_toggle:
				if do_sprint or (is_crouching and can_stand):
					is_crouching = false
					wanna_stand = true
					state = State.STATE_WALKING
					return
	
			is_crouching = true
			_crouch(delta)
			_walk(delta, 0.75)
	
		State.STATE_CLAMBERING_RISE:
			var pos = global_transform.origin
			var clamber_target = Vector3(pos.x, clamber_destination.y, pos.z)
			global_transform.origin = lerp(pos, clamber_target, 0.1)
	
			var d = pos - clamber_target
			if d.length() < 0.1:
				state = State.STATE_CLAMBERING_LEDGE
				return
	
		State.STATE_CLAMBERING_LEDGE:
			#_audio_player.play_clamber_sound(false)
			var pos = global_transform.origin
			global_transform.origin = lerp(pos, clamber_destination, 0.1)

			var d = global_transform.origin - clamber_destination
			if d.length() < 0.1:
				is_clambering = false
				global_transform.origin = clamber_destination
				if clamberable_obj and clamberable_obj is RigidBody:   # Altered to allow statics
					clamberable_obj.mode = 0

				if is_crouching:
					state = State.STATE_CROUCHING
					return
				state = State.STATE_WALKING
				return
	move_effect()


func slow_down(state : PhysicsDirectBodyState):
	state.linear_velocity = state.linear_velocity.normalized() * min(state.linear_velocity.length(), move_speed)


func damage(value : float, type : int, on_hitbox : Hitbox):
	if self._alive:
		self.current_health -= self._type_damage_multiplier[type] * value
		self.emit_signal("is_hit", current_health)
	
		if self.current_health <= 0:
			self._alive = false
			self.emit_signal("character_died")
	
			if self.name != "Player":
				collision_shape.disabled = true
				print("Character died")
				self.queue_free()
#				skeleton.physical_bones_start_simulation()   # This ragdolls when it's working


func _get_surface_type() -> Array:
	var cell_index = GameManager.game.level.world_data.get_cell_index_from_local_position(transform.origin)
	var floor_type = GameManager.game.level.world_data.get_cell_surfacetype(cell_index)
	
	match floor_type:
		
		SurfaceType.WOOD:
			return _audio_player._wood_footstep_sounds
	
		SurfaceType.CARPET:
			return _audio_player._carpet_footstep_sounds
	
		SurfaceType.STONE:
			return _audio_player._stone_footstep_sounds
	
		SurfaceType.WATER:
			return _audio_player._water_footstep_sounds
	
		SurfaceType.GRAVEL:
			return _audio_player._gravel_footstep_sounds
	
		SurfaceType.METAL:
			return _audio_player._metal_footstep_sounds
	
		SurfaceType.TILE:
			return _audio_player._tile_footstep_sounds
	
	return _audio_player._footstep_sounds


# Apparently not used
#func _handle_player_sound_emission() -> void:
#	_audio_player._footstep_sounds = _get_surface_type()


func _walk(delta, speed_mod : float = 1.0) -> void:
	move_dir = character_state.move_direction
	move_dir = move_dir.rotated(Vector3.UP, rotation.y)
	
	if do_sprint and stamina > 0 and is_reloading == false and is_moving_forward and !is_jumping:
		if is_crouching:
			if can_stand:
				is_crouching = false
				wanna_stand = true
				state = State.STATE_WALKING
			else:
				return
		
		# Sprint speed is walk speed plus stamina * a number, so player slows down as runs longer
		move_dir *= (1.2 + ((stamina / 500) * 0.3))
		change_stamina(-0.3)
	else:
		move_dir *= 0.8
		if !do_sprint:
			change_stamina(0.3)
	
	var y_velo = velocity.y
	
	var v1 = speed * move_dir - velocity * Vector3(move_drag, 0, move_drag)
	var v2 = Vector3.DOWN * gravity * delta
	
	velocity += v1 + v2
	
	grounded = is_on_floor() or _ground_checker.is_colliding()
	
	if is_crouching and is_jumping:
		velocity = move_and_slide((velocity) + get_floor_velocity(),
				Vector3.UP, true, 4, PI / 4, false)
	else:
		velocity = move_and_slide((velocity * speed_mod) + get_floor_velocity(),
				Vector3.UP, true, 4, PI / 4, false)
	
	if move_dir == Vector3.ZERO:
		is_player_moving = false
		self.emit_signal("is_moving", is_player_moving)
	else:
		is_player_moving = true
		self.emit_signal("is_moving", is_player_moving)
	
	if is_on_floor() and is_jumping:   # previously had: and _camera.stress < 0.1
		self.emit_signal("player_landed")
		_audio_player.play_land_sound()
		_camera.add_stress(0.25)
	
	grounded = is_on_floor()
	
	if !grounded and y_velo < velocity.y:
		velocity.y = y_velo
	
	if grounded:
		velocity.y -= 0.01
		is_jumping = false
	
	if is_clambering:
		return
	
	if do_jump:
		if is_crouching:
			pass
		elif state != State.STATE_WALKING:
			return
	
		var c = _clamber_m.attempt_clamber(is_crouching, is_jumping)
		if c != Vector3.ZERO:
			if is_clamberable:
				clamberable_obj = is_clamberable
				if clamberable_obj is RigidBody:   # To allow static objects
					clamberable_obj.mode = 1
			clamber_destination = c
			state = State.STATE_CLAMBERING_RISE
			is_clambering = true
			_audio_player.play_clamber_sound(true)
			do_jump = false
			return
		
		if is_jumping or !is_on_floor():
			do_jump = false
			return
	
		# This is the actual jump
		velocity.y = jump_force
		is_jumping = true
		do_jump = false
		return
	
	do_jump = false
	
	if velocity.length() > 0.1 and grounded and not _audio_player.movement_audio.playing and is_to_move:
		if is_crouching:
			_audio_player.play_footstep_sound(-1.0, 0.1, -20)
		elif do_sprint and is_moving_forward:
			_audio_player.play_footstep_sound(5.0, 1.5)
		else:
			_audio_player.play_footstep_sound(5.0, 1.0)


func _crouch(delta : float) -> void:
	wanna_stand = false
	
	if !_collider.disabled:
		_crouch_collider.set_deferred("disabled", false)
		_collider.set_deferred("disabled", true)
	
	var from = mainhand_equipment_root.transform.origin.y
	mainhand_equipment_root.transform.origin.y = lerp(from, crouch_equipment_target_pos, 0.08)
	
	from = offhand_equipment_root.transform.origin.y
	offhand_equipment_root.transform.origin.y = lerp(from, crouch_equipment_target_pos, 0.08)
	
	if !is_on_floor() and !is_jumping:
		velocity.y -= 5 * (gravity * delta)
	else:
		velocity.y -= 0.05
	
	if is_player_crouch_toggle:
		return
	
	if do_sprint or (!do_crouch and state == State.STATE_CROUCHING):
		if can_stand:
			state = State.STATE_WALKING
			wanna_stand = true
			return


func check_state_animation(delta):
	var forwards_velocity
	var sideways_velocity
	#if the character is moving sets the velocity to it's movement blendspace2D to create a strafing effect
	
	forwards_velocity = -global_transform.basis.z.dot(velocity)
	sideways_velocity = global_transform.basis.x.dot(velocity)
	
	# This code checks the current item equipped by the player and updates the current_mainhand_item_animation to correspond to it 
	if self.name == "Cultist":
		if current_mainhand_item_animation == hold_states.MELEE_ITEM:
			
			if state == State.STATE_CROUCHING:
				animation_tree.set("parameters/Equipped_state/current",1)
				animation_tree.set("parameters/Normal_state/current",4)
				
			if move_dir == Vector3.ZERO and ! state == State.STATE_CROUCHING:
				animation_tree.set("parameters/Equipped_state/current",1)
				animation_tree.set("parameters/Normal_state/current",0)
				
			elif move_dir == Vector3.ZERO and state == State.STATE_CROUCHING :
				animation_tree.set("parameters/Equipped_state/current",1)
				animation_tree.set("parameters/Normal_state/current",4)
				
			elif not move_dir == Vector3.ZERO and ! state == State.STATE_CROUCHING and do_sprint == false:
				animation_tree.set("parameters/Equipped_state/current",1)
				animation_tree.set("parameters/Normal_state/current",1)
				animation_tree.set("parameters/walk_strafe/blend_position", Vector2(sideways_velocity, forwards_velocity))
				
			elif not move_dir == Vector3.ZERO and state == State.STATE_CROUCHING and do_sprint == false:
				animation_tree.set("parameters/Equipped_state/current",1)
				animation_tree.set("parameters/Normal_state/current",5)
				animation_tree.set("parameters/crouch_strafe/blend_position", Vector2(sideways_velocity, forwards_velocity))
				
			elif not move_dir == Vector3.ZERO and do_sprint == true:
				animation_tree.set("parameters/Equipped_state/current",1)
				animation_tree.set("parameters/Normal_state/current",2)
				
		elif current_mainhand_item_animation == hold_states.SMALL_GUN_ITEM:
			
			if state == State.STATE_CROUCHING:
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",2)
				animation_tree.set("parameters/Gun_transition/current",0)
				animation_tree.set("parameters/Small_guns_transitions/current",4)
				
			if move_dir == Vector3.ZERO and ! state == State.STATE_CROUCHING:
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",2)
				animation_tree.set("parameters/Gun_transition/current",0)
				animation_tree.set("parameters/Small_guns_transitions/current",0)
				
			elif move_dir == Vector3.ZERO and state == State.STATE_CROUCHING :
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",2)
				animation_tree.set("parameters/Gun_transition/current",0)
				animation_tree.set("parameters/Small_guns_transitions/current",4)
				
			elif not move_dir == Vector3.ZERO and ! state == State.STATE_CROUCHING and do_sprint == false:
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",2)
				animation_tree.set("parameters/Gun_transition/current",0)
				animation_tree.set("parameters/Small_guns_transitions/current",1)
				animation_tree.set("parameters/Pistol_strafe/blend_amount",1)
				animation_tree.set("parameters/Pistol_strafe_vector/blend_position", Vector2(sideways_velocity, forwards_velocity))
				
			elif not move_dir == Vector3.ZERO and state == State.STATE_CROUCHING and do_sprint == false:
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",2)
				animation_tree.set("parameters/Gun_transition/current",0)
				animation_tree.set("parameters/Small_guns_transitions/current",3)
				animation_tree.set("parameters/Pistol_crouch_strafe/blend_amount",1)
				animation_tree.set("parameters/Pistol_crouch_strafe_vector/blend_position", Vector2(sideways_velocity, forwards_velocity))
				
			elif not move_dir == Vector3.ZERO and do_sprint == true:
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",2)
				animation_tree.set("parameters/Gun_transition/current",0)
				animation_tree.set("parameters/Small_guns_transitions/current",2)
				animation_tree.set("parameters/small_gun_run_blend/blend_amount",1)

		elif current_mainhand_item_animation == hold_states.LARGE_GUN_ITEM:
			
			if state == State.STATE_CROUCHING:
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",2)
				animation_tree.set("parameters/Gun_transition/current",1)
				animation_tree.set("parameters/Big_guns_transition/current",4)
				
			if move_dir == Vector3.ZERO and ! state == State.STATE_CROUCHING:
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",2)
				animation_tree.set("parameters/Gun_transition/current",1)
				animation_tree.set("parameters/Big_guns_transition/current",0)
				
			elif move_dir == Vector3.ZERO and state == State.STATE_CROUCHING :
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",2)
				animation_tree.set("parameters/Gun_transition/current",1)
				animation_tree.set("parameters/Big_guns_transition/current",4)
				
			elif not move_dir == Vector3.ZERO and ! state == State.STATE_CROUCHING and do_sprint == false:
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",2)
				animation_tree.set("parameters/Gun_transition/current",1)
				animation_tree.set("parameters/Big_guns_transition/current",1)
				animation_tree.set("parameters/Rifle_Strafe/blend_amount",1)
				animation_tree.set("parameters/Rifle_strafe_vector/blend_position", Vector2(sideways_velocity, forwards_velocity))
				
			elif not move_dir == Vector3.ZERO and state == State.STATE_CROUCHING and do_sprint == false:
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",2)
				animation_tree.set("parameters/Gun_transition/current",1)
				animation_tree.set("parameters/Big_guns_transition/current",3)
				animation_tree.set("parameters/Rifle_crouch/blend_amount",1)
				animation_tree.set("parameters/Crouch_Rifle_vector/blend_position", Vector2(sideways_velocity, forwards_velocity))
				
			elif not move_dir == Vector3.ZERO and do_sprint == true:
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",2)
				animation_tree.set("parameters/Gun_transition/current",1)
				animation_tree.set("parameters/Big_guns_transition/current",2)
				animation_tree.set("parameters/Rifle_gun_run_blend/blend_amount",1)
				
		elif current_mainhand_item_animation == hold_states.LARGE_GUNS_ADS:
			
			if state == State.STATE_CROUCHING:
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",0)
				animation_tree.set("parameters/ADS_Rifle_state/current",4)
				
			if move_dir == Vector3.ZERO and ! state == State.STATE_CROUCHING:
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",0)
				animation_tree.set("parameters/ADS_Rifle_state/current",0)
				
			elif move_dir == Vector3.ZERO and state == State.STATE_CROUCHING :
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",0)
				animation_tree.set("parameters/ADS_Rifle_state/current",4)
				
			elif not move_dir == Vector3.ZERO and ! state == State.STATE_CROUCHING and do_sprint == false:
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",0)
				animation_tree.set("parameters/ADS_Rifle_state/current",1)
				animation_tree.set("parameters/Rifle_ADS_strafe/blend_amount",1)
				animation_tree.set("parameters/Rifle_ADS_strafe_vector/blend_position", Vector2(sideways_velocity, forwards_velocity))
				
			elif not move_dir == Vector3.ZERO and state == State.STATE_CROUCHING and do_sprint == false:
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",0)
				animation_tree.set("parameters/ADS_Rifle_state/current",3)
				animation_tree.set("parameters/Rifle_ADS_crouch/blend_amount", 1)
				animation_tree.set("parameters/Rifle_ADS_crouch_vector/blend_position", Vector2(sideways_velocity, forwards_velocity))
				
			elif not move_dir == Vector3.ZERO and do_sprint == true:
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",0)
				animation_tree.set("parameters/ADS_Rifle_state/current",2)
				animation_tree.set("parameters/ADS_Rifle_Run/blend_amount",1)
				
		elif current_mainhand_item_animation == hold_states.SMALL_GUN_ADS:
			
			if state == State.STATE_CROUCHING:
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",1)
				animation_tree.set("parameters/ADS_Pistol_state/current",4)
				
			if move_dir == Vector3.ZERO and ! state == State.STATE_CROUCHING:
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",1)
				animation_tree.set("parameters/ADS_Pistol_state/current",0)
				
			elif move_dir == Vector3.ZERO and state == State.STATE_CROUCHING :
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",1)
				animation_tree.set("parameters/ADS_Pistol_state/current",4)
				
			elif not move_dir == Vector3.ZERO and ! state == State.STATE_CROUCHING and do_sprint == false:
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",1)
				animation_tree.set("parameters/ADS_Pistol_state/current",1)
				animation_tree.set("parameters/One_Handed_ADS_Strafe/blend_amount",1)
				animation_tree.set("parameters/One_Handed_ADS_Strafe_Vector/blend_position", Vector2(sideways_velocity, forwards_velocity))
				
			elif not move_dir == Vector3.ZERO and state == State.STATE_CROUCHING and do_sprint == false:
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",1)
				animation_tree.set("parameters/ADS_Pistol_state/current",3)
				animation_tree.set("parameters/One_Handed_ADS_Crouch/blend_amount", 1)
				animation_tree.set("parameters/One_Handed_ADS_Crouch_Vector/blend_position", Vector2(sideways_velocity, forwards_velocity))
				
			elif not move_dir == Vector3.ZERO and do_sprint == true:
				animation_tree.set("parameters/Equipped_state/current",0)
				animation_tree.set("parameters/ADS_State/current",1)
				animation_tree.set("parameters/ADS_Pistol_state/current",2)
				animation_tree.set("parameters/One_Handed_ADS_Run/blend_amount",1)

# Checks if the character is on the ground if not plays the falling animation
	if !grounded and !_ground_checker.is_colliding():
		animation_tree.set("parameters/Falling/active",true)
	else:
		animation_tree.set("parameters/Falling/active",false)


func check_current_item_animation():
		# This code checks the current item type the player is equipping and set the animation that matches that item in the animation tree
		var mainhand_object = inventory.current_mainhand_slot
		var offhand_object = inventory.current_offhand_slot
		
		# temporary hack (issue #409) - not sure it's necessary
#		if not is_instance_valid(inventory.hotbar[mainhand_object]):
#			inventory.hotbar[mainhand_object] = null
		
		if inventory.hotbar[mainhand_object] is GunItem:
			if inventory.hotbar[mainhand_object].item_size == 0:
				current_mainhand_item_animation = hold_states.SMALL_GUN_ITEM
			else:
				current_mainhand_item_animation = hold_states.LARGE_GUN_ITEM
#		elif inventory.hotbar[main_hand_object] is LanternItem or inventory.hotbar[off_hand_object] is LanternItem:
#			print("Carried Lantern")
			#update this to work for items animations
		elif inventory.hotbar[mainhand_object] is MeleeItem:
			current_mainhand_item_animation = hold_states.MELEE_ITEM
			print("Melee Item")


func change_stamina(amount: float) -> void:
	stamina = min(600, max(0, stamina + amount))


func _on_ClamberableChecker_body_entered(body):
	if body.is_in_group("CLAMBERABLE"):
		is_clamberable = body
#
#	if event.is_action_pressed("crouch"):
#		if $crouch_timer.is_stopped(): # && !$AnimationTree.get(roll_active):
#			$crouch_timer.start()
#			$AnimationTree.tree_root.get_node("cs_transition").xfade_time = (velocity.length() + 1.5)/ 15.0
#			crouch_stand_target = 1 - crouch_stand_target
#			$AnimationTree.set(cs_transition, crouch_stand_target)


func move_effect():
	# Plays the belt bobbing animation if the player is moving 
	if velocity != Vector3.ZERO:
		additional_animations.play("Belt_bob", -1, velocity.length() / 2)


func _on_Inventory_mainhand_slot_changed(previous, current):
	# Checks if there is something currently equipped, else does nothing
	if inventory.hotbar[current] != null :
		pass
	else:
		current_mainhand_item_animation = hold_states.MELEE_ITEM
		mainhand_animation = Animation_state.NOT_EQUIPPED
