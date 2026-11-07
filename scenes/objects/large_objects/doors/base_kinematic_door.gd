extends Node3D
class_name BaseKinematicDoor

#
# This is a simplified door model, with toggle open/close
# Done due to limitations in Godot 3 making it difficult to implement
# a fully simulated Rigid Body door
#


enum DoorState {
	OPEN,
	CLOSED,
	AUTO_CLOSING,
	STUCK,
	BROKEN
}

enum DoorType {
	WOODEN,
	METAL_GATE,
	SOLID_METAL,
}

# Emitted when the swing reaches one of its ends:
# "wall" at the full open angle, "frame" at the fully closed end.
signal door_hit_limit(limit_kind : StringName)

# Emitted when a locked door is unlocked by a key from the character's inventory.
signal door_unlocked(lock_id : int)

## Door-type parameter matrix (issue #17 body: wooden, metal gate, solid metal
## with eye slot). Per-type gameplay values live in the tables below. Visual
## variants are wired only where a mesh actually fits the 1 x 2 m door frame:
## WOODEN uses the embedded Door_Simple1 leaf; METAL_GATE and SOLID_METAL have
## meshes in resources/models/gridmap/modular_doors/ModularPiecesExport.gltf
## (Door_Grate 1.40x2.27 m, Door_BigEntrance 1.27x5.87 m) but both are larger
## than the frame, so until a frame-fit decision they keep the wooden leaf
## visually while carrying their own gameplay parameters. Spawning-time scaling
## of those meshes is not allowed (CODE_STYLE.md section 9).
@export var door_type : int = DoorType.WOODEN : set = set_door_type

## Orthogonal to STUCK and to the open/closed state, so STUCK + LOCKED can
## combine (locked rattles on tap, stuck does not). Kept a plain exported var
## so save capture and world gen custom properties can read and write it.
@export var is_locked : bool = false
## Key that unlocks this door, matched against Inventory.keychain. 0 matches a
## key whose key_id is 0; there is no master/skeleton key yet.
@export var lock_id : int = 0
## Orthogonal bar state: a barred door cannot be opened (by player or NPC)
## until the bar is lifted. Lifted only from the reachable side.
@export var is_barred : bool = false
## Which face of the closed door the bar is mounted on, in door local Z:
## +1 = the +Z face, -1 = the -Z face. Generation hook point for T6 bars.
@export var bar_reachable_side : int = 1

# Per-type defaults, applied by set_door_type. Indestructible doors ignore all
# damage (issue: solid metal cannot be broken).
const DOOR_TYPE_DEFAULT_HEALTH := {
	DoorType.WOODEN: 75.0,
	DoorType.METAL_GATE: 150.0,
	DoorType.SOLID_METAL: 300.0,
}
const DOOR_TYPE_IMMUNE_ATTACK_TYPES := {
	DoorType.WOODEN: [],
	# A grate passes blades and bullets through the gaps; only blunt force bends it.
	DoorType.METAL_GATE: [GlobalConsts.AttackTypes.SLASHING, GlobalConsts.AttackTypes.PIERCING],
	DoorType.SOLID_METAL: [],
}
const DOOR_TYPE_INDESTRUCTIBLE := {
	DoorType.WOODEN: false,
	DoorType.METAL_GATE: false,
	DoorType.SOLID_METAL: true,
}

@export var health : float = 75.0

var broken_door_scene : PackedScene = preload("res://scenes/objects/large_objects/doors/base_broken_door.tscn")

var navigation_areas : Array
var door_state : int = DoorState.CLOSED: set = set_door_state

var door_move_time : float = 0.5
var door_open_angle : float = deg_to_rad(100)
var door_close_threshold : float = deg_to_rad(5)
var door_speed : float = door_open_angle/door_move_time
var door_auto_close_speed : float = 0.05*door_speed
var door_auto_close_delay_min : float = 25.0
var door_auto_close_delay_max : float = 55.0
var door_should_move : float = false
var door_stuck_on_close_probability = 0.01   # TODO make this optional in settings menu
var time_to_auto_close = 0.0
# Sentinel value that disables the auto-close timer (see reset_auto_close_timer)
const AUTO_CLOSE_DISABLED = 55555

# Amnesia-style physical swing model (owner rulings, doors lane):
# while HELD the hinge critically-damped-follows the player's hand with a
# heavy lag; on RELEASE the current angular velocity carries over into a
# damped inertial coast (a stationary release just stays put); arriving at
# the closed frame, momentum below the latch threshold is absorbed and the
# door settles shut, momentum above it bounces the door back open.
enum FollowMode {
	FREE,
	HOLD_FOLLOW,
}
# Spring stiffness for the hand follow (rad/s^2 per rad of error). Critically
# damped: damping below is 2 * sqrt(stiffness). Lower = heavier, laggier feel.
const HOLD_FOLLOW_STIFFNESS := 10.0
const HOLD_FOLLOW_DAMPING := 6.32
const HOLD_MAX_SPEED := 6.0                       # rad/s cap while held
# Coast damping for the inertial release (1/s, exponential-ish decay)
const COAST_DAMPING := 1.1
# Below this angular speed (rad/s) a released door is considered stationary
# and does not creep (owner: a nearly stationary release stays put)
const STATIC_FRICTION_SPEED := 0.08
# Closing momentum at or below this threshold is eaten by the latch (settles
# shut); above it the door bounces back open (owner: "within reason")
const LATCH_ABSORB_SPEED := 0.8
const LATCH_RESTITUTION := 0.55
# Same absorb/bounce split where the leaf meets the wall at full open
const WALL_ABSORB_SPEED := 0.8
const WALL_RESTITUTION := 0.4
# NPC auto open/close shoves (rad/s); the close is soft so it settles in the
# latch instead of bouncing
const NPC_OPEN_SHOVE_SPEED := 1.5
const NPC_CLOSE_SHOVE_SPEED := 0.5
# Body contact push (owner ruling: a door has REAL MASS against the player's
# body). Walking into a closed leaf drives the same momentum model the hand
# and NPC shoves use: contact maps the body's approach speed to an angular
# velocity target scaled to the door type's feel mass, the hinge moves toward
# it at a limited rate (the weight feel), the existing COAST_DAMPING decays
# it on release, and the latch absorbs light brushes below the break speed.
# Sustained contact ACCUMULATES press (owner feedback: a continuing push must
# accelerate the door, not hold one speed): while a body keeps pressing the
# leaf, its press memory grows at PUSH_ACCUM_RATE (slower for heavier types),
# so the chased target keeps extending up to the terminal PUSH_MAX_SPEED; a
# light brush below PUSH_BREAK_SPEED never accumulates and stays absorbed.
const PUSH_SENSOR_DEPTH := 0.3      # m: sensor slab thickness around the leaf plane
const PUSH_BREAK_SPEED := 0.45      # m/s approach needed to move the leaf; a light brush below this is absorbed
const PUSH_GAIN := 0.55             # rad/s of swing target per unit of press memory (wooden reference)
const PUSH_ACCEL := 3.0             # rad/s^2 while the hinge chases the press target (wooden reference)
const PUSH_MAX_SPEED := 2.2         # rad/s terminal cap from body push (wooden reference)
const PUSH_ACCUM_RATE := 6.0        # press memory units gained per second of sustained contact (wooden reference)
const PUSH_MAX_MEMORY := 6.0        # press memory cap (units)
# Heavier door types are slower to push: target, accel and cap are divided by this
const PUSH_TYPE_MASS := {
	DoorType.WOODEN: 1.0,
	DoorType.METAL_GATE: 1.7,
	DoorType.SOLID_METAL: 2.4,
}
# Height above the hinge origin where the hand ray meets the swing plane
const HOLD_PLANE_HEIGHT := 1.0

var follow_mode : int = FollowMode.FREE
var _angular_velocity := 0.0
var _target_angle := 0.0
var _npc_motion := false
# Thin Area3D slab around the leaf plane; overlapping bodies pressing into
# the leaf drive the body-push model. Built in _ready() like the sound players.
var _push_sensor : Area3D
# Per-body press memory: the strongest recent approach speed while the body
# is inside the sensor slab, kept while the contact lasts so a sustained
# walking push keeps driving the leaf
var _push_press_memory : Dictionary = {}
# True on frames where a body press drove the hinge (suppresses the static
# friction clamp for that frame)
var _push_driving := false

# NPC pass through tracking: the non-Player body that opened the door gets a
# normal-speed close started behind it after it leaves the doorway area.
var npc_opener : Node = null
var npc_close_delay : float = 0.6
var npc_close_pending : bool = false
var _npc_close_timer : Timer

# Thud played when the swing hits either end. Reuses the licensed wood impact
# asset from resources/sounds/impacts/ (see the license file next to it).
const DOOR_HIT_SOUND_STREAM = preload("res://resources/sounds/impacts/534956__joedinessound__arrow-wood-impact-single-archery-01.ogg")
var door_hit_wall_pitch : float = 0.8
var door_hit_frame_pitch : float = 1.0
var _door_hit_sound : AudioStreamPlayer3D
var _at_open_limit : bool = false
var _at_close_limit : bool = false

# Lock and bar feedback players, built in _ready() like the hit thud. All
# streams are already licensed (license files sit next to each asset).
const LOCK_RATTLE_SOUND_STREAM = preload("res://resources/sounds/locks/164638__deleted-user-2104797__lock-rattle-3.wav")
const KEY_INSERT_SOUND_STREAM = preload("res://resources/sounds/locks/342617__spacejoe__lock-1-insert-key-1.wav")
const UNLOCK_SOUND_STREAM = preload("res://resources/sounds/locks/536414__rudmer-rotteveel__small-padlock-opening.wav")
var _lock_rattle_sound : AudioStreamPlayer3D
var _key_insert_sound : AudioStreamPlayer3D
var _unlock_sound : AudioStreamPlayer3D

@onready var door_body = %DoorBody
@onready var interactable_area : Interactable = %DoorBody/Interactable
@onready var door_hinge_z_axis = %DoorHingeZAxis
@onready var open_block_detector = %OpenBlockDetector
@onready var close_block_detector = %CloseBlockDetector
@onready var doorway_gaps_filler = %DoorwayGapsFiller
@onready var npc_detector = %NpcDetector
@onready var npc_check_timer: Timer = $NpcCheckTimer
@onready var broken_door_origin: Node3D = %BrokenDoorOrigin
@onready var navigation_obstacle_3d : NavigationObstacle3D = $NavigationObstacle3D
#@onready var navigation: Navigation = $Navigation

@onready var door_open_sound : AudioStreamPlayer3D = $Sounds/DoorOpen
@onready var door_close_sound : AudioStreamPlayer3D = $Sounds/DoorClose
@onready var door_shake_sound : AudioStreamPlayer3D = $Sounds/DoorShakeSound
@onready var door_kick_ineffective_sound : AudioStreamPlayer3D = $Sounds/DoorKickIneffectiveSound
@onready var door_kick_effective_sound : AudioStreamPlayer3D = $Sounds/DoorKickEffectiveSound
@onready var door_break_sound : AudioStreamPlayer3D = $Sounds/DoorBreakSound


func _ready():
	# Opt into hold-to-interact (Amnesia style, owner ruling): the controller
	# fires interact() on a held press past the grab threshold, and the tap
	# call still arrives so the locked/barred/stuck branches can react
	if is_instance_valid(interactable_area):
		interactable_area.hold_interact = true
		# The controller only sees the Area3D; register the door as the
		# hold-follow owner so its drag feed and release are relayed here.
		interactable_area.hold_follow_owner = self

	# Hit-limit thud player, built here to keep the tscn untouched
	_door_hit_sound = AudioStreamPlayer3D.new()
	_door_hit_sound.name = "DoorHitSound"
	_door_hit_sound.stream = DOOR_HIT_SOUND_STREAM
	_door_hit_sound.bus = &"Effects"
	$Sounds.add_child(_door_hit_sound)

	# Close-behind timer for the NPC opener
	_npc_close_timer = Timer.new()
	_npc_close_timer.name = "NpcCloseTimer"
	_npc_close_timer.one_shot = true
	_npc_close_timer.wait_time = npc_close_delay
	_npc_close_timer.timeout.connect(_on_NpcCloseTimer_timeout)
	add_child(_npc_close_timer)
	npc_detector.body_exited.connect(_on_NpcDetector_body_exited)

	# Lock and bar feedback players, built here to keep the tscn untouched
	_lock_rattle_sound = _make_lock_sound(LOCK_RATTLE_SOUND_STREAM, "LockRattleSound")
	_key_insert_sound = _make_lock_sound(KEY_INSERT_SOUND_STREAM, "KeyInsertSound")
	_unlock_sound = _make_lock_sound(UNLOCK_SOUND_STREAM, "UnlockSound")

	# Body push sensor: a slab slightly wider and taller than the leaf,
	# centered on the leaf plane so it protrudes PUSH_SENSOR_DEPTH/2 past
	# each face. Built here to keep the tscn untouched.
	_push_sensor = Area3D.new()
	_push_sensor.name = "PushSensor"
	# Layer 0: nothing may target the sensor (it otherwise eats the player's
	# interaction raycast in place of the Interactable); it only watches
	# with its own mask
	_push_sensor.collision_layer = 0
	_push_sensor.collision_mask = 19
	_push_sensor.monitorable = false
	var push_shape := CollisionShape3D.new()
	push_shape.name = "PushSensorShape"
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 2.0, PUSH_SENSOR_DEPTH)
	push_shape.shape = box
	_push_sensor.add_child(push_shape)
	door_body.add_child(_push_sensor)


func _make_lock_sound(stream : AudioStream, sound_name : String) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = sound_name
	player.stream = stream
	player.bus = &"Effects"
	$Sounds.add_child(player)
	return player


func set_door_type(value : int):
	door_type = clampi(value, 0, DoorType.size() - 1)
	# Applying a type applies its gameplay defaults. Health stays overridable
	# afterwards (world gen or a designer can still set health directly).
	health = DOOR_TYPE_DEFAULT_HEALTH[door_type]


func _type_is_indestructible() -> bool:
	return DOOR_TYPE_INDESTRUCTIBLE.get(door_type, false)


func _type_is_immune(damage_type : int) -> bool:
	return DOOR_TYPE_IMMUNE_ATTACK_TYPES.get(door_type, []).has(damage_type)


func _physics_process(delta):
	if not is_instance_valid(door_hinge_z_axis):
		return
	match door_state:
		DoorState.BROKEN, DoorState.STUCK:
			return
	_push_driving = false
	var angle : float = door_hinge_z_axis.rotation.y
	match follow_mode:
		FollowMode.HOLD_FOLLOW:
			# Critically damped hand follow: the hinge lags the hand with a
			# heavy pull feel, and the follow's angular velocity is the real
			# momentum that carries over on release.
			var error := _target_angle - angle
			_angular_velocity += (HOLD_FOLLOW_STIFFNESS * error - HOLD_FOLLOW_DAMPING * _angular_velocity) * delta
			_angular_velocity = clampf(_angular_velocity, -HOLD_MAX_SPEED, HOLD_MAX_SPEED)
			angle += _angular_velocity * delta
			angle = _clamp_angle(angle)
		FollowMode.FREE:
			if _npc_motion:
				# An NPC-initiated coast aborts while a body sits in its arc
				var detector : Area3D = close_block_detector if _angular_velocity < 0.0 else open_block_detector
				if not _is_arc_clear(detector):
					_angular_velocity = 0.0
				# Self-heal: an NPC that despawns mid-coast never fires the
				# exit handler, which would leave _npc_motion stuck true and
				# permanently disable the player's body push lane
				elif npc_opener == null and not npc_close_pending \
						and absf(_angular_velocity) < STATIC_FRICTION_SPEED:
					_npc_motion = false
			if not _npc_motion:
				# Body contact push drives the same momentum model
				_push_driving = _apply_body_push(delta)
			# Inertial coast with decay; the stationary case just stays put
			_angular_velocity *= maxf(0.0, 1.0 - COAST_DAMPING * delta)
			if absf(_angular_velocity) < STATIC_FRICTION_SPEED and not _push_driving:
				# A body press actively driving the hinge must not be eaten
				# by the per-frame static friction clamp
				_angular_velocity = 0.0
			angle += _angular_velocity * delta
			angle = _apply_limits(angle)
	door_hinge_z_axis.rotation.y = angle
	_update_state_from_motion(angle)


func _clamp_angle(angle : float) -> float:
	return clampf(angle, 0.0, door_open_angle)


func _apply_limits(angle : float) -> float:
	# Closed frame latch: slow momentum is absorbed and the door settles shut,
	# fast momentum bounces it back open (owner ruling, "within reason")
	if angle <= 0.0:
		var incoming := -_angular_velocity
		angle = 0.0
		if _angular_velocity < -STATIC_FRICTION_SPEED:
			if incoming <= LATCH_ABSORB_SPEED:
				_angular_velocity = 0.0
				_settle_closed()
			else:
				_angular_velocity = incoming * LATCH_RESTITUTION
				_hit_limit(&"frame")
		else:
			_angular_velocity = 0.0
	# Open end: the leaf meets the wall with the same absorb/bounce split
	if angle >= door_open_angle:
		var incoming := _angular_velocity
		angle = door_open_angle
		if _angular_velocity > STATIC_FRICTION_SPEED:
			if incoming <= WALL_ABSORB_SPEED:
				_angular_velocity = 0.0
				_settle_open()
			else:
				_angular_velocity = -incoming * WALL_RESTITUTION
				_hit_limit(&"wall")
		else:
			_angular_velocity = 0.0
	return angle


func _settle_closed():
	# This is when the door actually closes
	if not _at_close_limit:
		_at_close_limit = true
		_hit_limit(&"frame")
	door_should_move = false
	_npc_motion = false
	_stop_swing_sounds()
	if randf() < door_stuck_on_close_probability:
		self.door_state = DoorState.STUCK


func _settle_open():
	if not _at_open_limit:
		_at_open_limit = true
		_hit_limit(&"wall")
	_npc_motion = false
	_stop_swing_sounds()


func _stop_swing_sounds():
	if is_instance_valid(door_open_sound):
		door_open_sound.stop()
	if is_instance_valid(door_close_sound):
		door_close_sound.stop()


func _update_state_from_motion(angle : float):
	# Logical marker only: CLOSED = resting against the frame, OPEN = anything
	# else (moving or held open). AUTO_CLOSING is no longer produced.
	var target_state := DoorState.OPEN
	if absf(_angular_velocity) < STATIC_FRICTION_SPEED and angle <= door_close_threshold:
		target_state = DoorState.CLOSED
	if door_state != target_state:
		self.door_state = target_state


func _is_arc_clear(detector : Area3D) -> bool:
	for obstacle in detector.get_overlapping_bodies():
		if not obstacle in [door_body, doorway_gaps_filler]:
			return false
	return true


## Body contact push (owner ruling: doors have real mass against the player).
## Contact maps the body's approach speed to an angular velocity target
## (PUSH_GAIN, feel mass scaled) and the hinge chases it at PUSH_ACCEL, so a
## shoulder push opens in a believable time and a light brush is absorbed by
## the latch. Approach comes from the body's velocity or, once a rigid body
## rests against the leaf (contact zeroes its inward velocity), from how
## fast it intrudes deeper into the sensor slab. Sustained contact holds the
## press until the body leaves the slab. Returns true when a press drove
## the hinge this frame.
func _apply_body_push(delta : float) -> bool:
	if not is_instance_valid(_push_sensor) or not is_instance_valid(door_body):
		return false
	var mass_factor : float = PUSH_TYPE_MASS.get(door_type, 1.0)
	var push_accel : float = PUSH_ACCEL / mass_factor
	var push_cap : float = PUSH_MAX_SPEED / mass_factor
	var basis_inverse : Basis = door_body.global_basis.inverse()
	var seen : Dictionary = {}
	var drove := false
	for body in _push_sensor.get_overlapping_bodies():
		if not is_instance_valid(body) or body == door_body or body == doorway_gaps_filler:
			continue
		var body_velocity : Vector3
		if body is RigidBody3D:
			body_velocity = body.linear_velocity
		elif body is CharacterBody3D:
			body_velocity = body.velocity
		else:
			# Static world geometry and props cannot press the leaf
			continue
		seen[body] = true
		var local_pos : Vector3 = door_body.to_local(body.global_position)
		var dist : float = absf(local_pos.z)
		# Which face the body is on decides the swing direction: a body on
		# the -Z face pressing toward +Z swings the door open, one on the
		# +Z face pressing toward -Z pushes it shut toward the latch.
		var side : float = 1.0 if local_pos.z >= 0.0 else -1.0
		var vel_into : float = -side * (basis_inverse * body_velocity).z
		var record : Array = _push_press_memory.get(body, [0.0, dist])
		var intrusion : float = clampf((record[1] - dist) / delta, 0.0, 6.0)
		var approach : float = clampf(maxf(vel_into, intrusion), 0.0, 6.0)
		# Sustained press: while the body stays in the slab its strongest
		# recent approach keeps driving the leaf; cleared when it leaves
		var memory : float = maxf(record[0], approach)
		# Sustained press accumulates (owner feedback: a continuing push must
		# accelerate the leaf, not hold one speed); a light brush below the
		# break speed never accumulates and stays absorbed by the latch
		if memory >= PUSH_BREAK_SPEED:
			memory = minf(memory + PUSH_ACCUM_RATE / mass_factor * delta, PUSH_MAX_MEMORY)
		_push_press_memory[body] = [memory, dist]
		if memory <= PUSH_BREAK_SPEED:
			continue
		var signed_desired : float = -side * memory * PUSH_GAIN / mass_factor
		# A push that drives the leaf shut must not close onto another body
		if signed_desired < 0.0 and not _is_arc_clear(close_block_detector):
			continue
		# The hinge chases the press target through the momentum model
		_angular_velocity = move_toward(_angular_velocity, signed_desired, push_accel * delta)
		_angular_velocity = clampf(_angular_velocity, -push_cap, push_cap)
		drove = true
		# Motion beginning from the closed frame unlatches and reports open
		if door_state == DoorState.CLOSED and signed_desired > 0.0:
			_at_open_limit = false
			_at_close_limit = false
			self.door_state = DoorState.OPEN
			door_close_sound.stop()
			if not door_open_sound.playing:
				door_open_sound.play()
	# Forget bodies that left the sensor slab
	for stale_body in _push_press_memory.keys():
		if not seen.has(stale_body):
			_push_press_memory.erase(stale_body)
	return drove


func _hit_limit(limit_kind : StringName):
	if is_instance_valid(_door_hit_sound) and not _door_hit_sound.playing:
		_door_hit_sound.pitch_scale = door_hit_wall_pitch if limit_kind == &"wall" else door_hit_frame_pitch
		_door_hit_sound.play()
	door_hit_limit.emit(limit_kind)


func set_door_state(value : int):
	if door_state != value:
		if value == DoorState.OPEN:
			reset_auto_close_timer()
	door_state = value


func reset_auto_close_timer():
	# Sentinel disabling auto-close: this feature didn't playtest well -
	# navigation is even more confusing if you can't rely on tracking which
	# doors you opened or not. The real delay logic stays on the line below.
	time_to_auto_close = AUTO_CLOSE_DISABLED
#	time_to_auto_close = rand_range(door_auto_close_delay_min, door_auto_close_delay_max)   # Actual logic


func _damage(damage, damage_type = GlobalConsts.AttackTypes.BLUDGEONING, direction : Vector3 = Vector3.ZERO, origin : Vector3 = position):
	if _type_is_indestructible():
		# Solid metal doors do not break; every hit is ineffective
		door_kick_ineffective_sound.play()
		return
	if _type_is_immune(damage_type):
		# Metal gates shrug off cutting and piercing hits
		door_kick_ineffective_sound.play()
		return
	if damage < 10:
		door_kick_ineffective_sound.play()
	else:
		door_kick_effective_sound.play()
		health -= damage
	if health <= 0:
		break_door(damage, damage_type, direction, origin)   # TODO: have a way for bomb to set middle param which is impulse direction (away from explosion)


func break_door(damage, damage_type = GlobalConsts.AttackTypes.BLUDGEONING, direction : Vector3 = Vector3.ZERO, origin : Vector3 = position):
	if _type_is_indestructible():
		return
	door_state = DoorState.BROKEN
	# The lock and the bar are destroyed with the door; keep the state readable
	is_locked = false
	is_barred = false
	door_break_sound.play()
	var global_door_transform = broken_door_origin.global_transform

	door_hinge_z_axis.queue_free()
	npc_detector.queue_free()
	npc_check_timer.queue_free()
	navigation_obstacle_3d.queue_free()

	var broken_door_instance : Node3D = broken_door_scene.instantiate()
	broken_door_instance.transform = global_transform.affine_inverse() * global_door_transform
	add_child(broken_door_instance)
	broken_door_instance.apply_impulse(origin, direction * damage, 1.0)


func _on_Interactable_character_interacted(character):
	# Locked takes precedence over every other state: a locked (even stuck)
	# door rattles the lock on tap, and auto-uses a matching key (owner ruling).
	if is_locked:
		_interact_locked(character)
		return
	# Barred comes next: the bar blocks the swing until it is lifted, and only
	# from the side it is mounted on.
	if is_barred:
		_interact_barred(character)
		return
	match door_state:
		DoorState.CLOSED, DoorState.AUTO_CLOSING:
			# Owner ruling: hold to swing, Amnesia style. A quick tap does
			# NOTHING on a normal door; only a held press past the grab
			# threshold grabs the leaf. Locked/barred/stuck branches above
			# still react to a tap.
			if not _interact_press_was_hold():
				return
			_begin_hold_follow()

		DoorState.OPEN:
			if not _interact_press_was_hold():
				return
			_begin_hold_follow()

		DoorState.STUCK:
			if !door_shake_sound.playing:
				door_shake_sound.play()


func _begin_hold_follow():
	if not is_instance_valid(door_hinge_z_axis):
		return
	follow_mode = FollowMode.HOLD_FOLLOW
	_npc_motion = false
	_at_open_limit = false
	_at_close_limit = false
	if door_state == DoorState.CLOSED or door_state == DoorState.AUTO_CLOSING:
		self.door_state = DoorState.OPEN
		door_close_sound.stop()
		if !door_open_sound.playing:
			door_open_sound.play()
	else:
		door_open_sound.stop()
		if !door_close_sound.playing:
			door_close_sound.play()


## While the player holds the door, the controller feeds the camera ray each
## frame; the hand point is projected onto the door's swing plane and the
## hinge target angle follows it (Amnesia drag model).
func interact_hold_update(origin : Vector3, dir : Vector3):
	if follow_mode != FollowMode.HOLD_FOLLOW:
		return
	if not is_instance_valid(door_hinge_z_axis):
		return
	var swing_plane := Plane(Vector3.UP, door_hinge_z_axis.global_position.y + HOLD_PLANE_HEIGHT)
	var hand = swing_plane.intersects_ray(origin, dir)
	if hand == null:
		return
	# Hand offset in DOOR-local space: the hinge marker supplies only the
	# pivot position (its own node basis is not world-aligned, so routing the
	# offset through to_local leaked the plane's y component into the swing
	# plane). Closed leaf points door-local -X, +Y rotation sweeps it toward
	# door-local +Z, so the angle is atan2(z, -x) in [0, open].
	var world_offset : Vector3 = hand - door_hinge_z_axis.global_position
	var local_v : Vector3 = global_basis.inverse() * world_offset
	_target_angle = clampf(atan2(local_v.z, -local_v.x), 0.0, door_open_angle)


## Release: the follow's current angular velocity carries over as real
## momentum into the damped coast; a nearly stationary release stays put.
func interact_hold_end():
	if follow_mode != FollowMode.HOLD_FOLLOW:
		return
	follow_mode = FollowMode.FREE
	if absf(_angular_velocity) < STATIC_FRICTION_SPEED:
		_angular_velocity = 0.0


func _shove_open():
	if not is_instance_valid(door_hinge_z_axis):
		return
	_npc_motion = false
	_angular_velocity = NPC_OPEN_SHOVE_SPEED
	door_close_sound.stop()
	if !door_open_sound.playing:
		door_open_sound.play()


## Into-room rule score: the more room-like side of a door wall. ROOM beats
## HALL beats everything else; equal scores keep the 3.x default orientation.
## Static so generation and tests share the single definition.
static func room_side_score(data : WorldData, cell : int) -> int:
	match data.get_cell_type(cell):
		data.CellType.ROOM:
			return 2
		data.CellType.HALL:
			return 1
		_:
			return 0


func _interact_press_was_hold() -> bool:
	return is_instance_valid(interactable_area) and interactable_area.interact_press_was_hold


func _interact_locked(character):
	if _character_has_key(character):
		_consume_key(character)
		is_locked = false
		_key_insert_sound.play()
		_unlock_sound.play()
		door_unlocked.emit(lock_id)
		# Auto-use on tap: the unlock also swings the door open right away
		if door_state == DoorState.CLOSED or door_state == DoorState.AUTO_CLOSING:
			self.door_state = DoorState.OPEN
			_shove_open()
	elif !is_instance_valid(_lock_rattle_sound) or not _lock_rattle_sound.playing:
		# No key: the lock rattles (a locked door rattles where a stuck one
		# does not; distinct sounds per the owner ruling)
		_lock_rattle_sound.play()


func _interact_barred(character):
	if _character_on_bar_side(character):
		# Lift the bar: the door becomes openable again. No bar prop mesh
		# exists yet, so the lift is state + sound only for v1.
		is_barred = false
		_unlock_sound.play()
	# From the other side the bar cannot be reached; nothing happens.


func _character_has_key(character) -> bool:
	var inventory = character.get("inventory") if character != null else null
	if inventory == null:
		return false
	var keychain = inventory.get("keychain")
	return keychain is Dictionary and keychain.get(lock_id, 0) > 0


func _consume_key(character):
	var keychain : Dictionary = character.get("inventory").get("keychain")
	keychain[lock_id] = keychain.get(lock_id, 0) - 1
	if keychain[lock_id] <= 0:
		keychain.erase(lock_id)


func _character_on_bar_side(character) -> bool:
	if character == null or not character is Node3D:
		return false
	var local_point := to_local((character as Node3D).global_position)
	return signi(int(local_point.z)) == bar_reachable_side


func _on_NpcDetector_body_entered(body):
	_open_for_npc(body)


func _on_NpcCheckTimer_timeout():
	if npc_close_pending:
		# Closing behind the opener, do not bang back open
		return
	for body in npc_detector.get_overlapping_bodies():
		_open_for_npc(body)


func _open_for_npc(body):
	if body is Player:
		return
	if is_barred or is_locked:
		# Enemies never lift bars (issue #17 TODO 19) and never unlock doors
		return
	if door_state == DoorState.CLOSED or door_state == DoorState.AUTO_CLOSING:
		# A cultist coming back through cancels the pending close behind it
		npc_close_pending = false
		_npc_close_timer.stop()
		npc_opener = body
		self.door_state = DoorState.OPEN
		_npc_motion = true
		_angular_velocity = NPC_OPEN_SHOVE_SPEED


func _on_NpcDetector_body_exited(body):
	if body == npc_opener and not npc_close_pending:
		npc_close_pending = true
		if is_instance_valid(_npc_close_timer):
			_npc_close_timer.start()


func _on_NpcCloseTimer_timeout():
	if not npc_close_pending:
		return
	npc_close_pending = false
	npc_opener = null
	if is_instance_valid(door_hinge_z_axis) and is_instance_valid(npc_detector):
		if door_state == DoorState.OPEN:
			# Normal-speed soft close behind the NPC: the coast freezes while
			# a body sits in the arc, and the latch settles it shut
			_npc_motion = true
			_angular_velocity = -NPC_CLOSE_SHOVE_SPEED
			door_open_sound.stop()
			if not door_close_sound.playing:
				door_close_sound.play()
