extends Node3D


# Broken door debris. Every direct child that is a RigidBody3D is a broken
# piece; apply_impulse shoves them with distance attenuation.

# Owner rulings (doors fix lane, November 2026): the T10 keep-active area and
# wake timer are removed entirely (the owner never wanted them; the 3.x
# debris had no sleeping interference and the timer defeated Jolt's
# sleep-based settle). The real jitter cause is the thin (~0.096 m deep)
# chunk boxes resting partially inside the floor collision, so after the
# break settles each piece is checked against the floor top plane (floor
# slabs sit at y = 0 per WorldData) and lifted minimally so it rests ON the
# floor surface instead of fighting the solver inside it.

# Per-piece oscillation watchdog (owner-mandated safety net): a piece whose
# velocity reverses N = 4 times within a 0.5 s window at speeds above
# 0.05 m/s is first frozen and lifted out above the floor (depenetrated);
# only if it still oscillates after that lift is it deleted. The shard is
# never deleted: matched by script global name, same idiom as
# pickable_item.gd (no shard pieces exist in the debris, the pattern is kept
# consistent).

const FLOOR_TOP_Y : float = 0.0
const SETTLE_GRACE : float = 1.0
# The penetration sweep runs repeatedly: pieces that come to rest embedded in
# the slab after the first grace period must still be lifted out (observed
# slow sliders resting 3 cm inside the floor 5 s after the break)
const SETTLE_SWEEP_INTERVAL : float = 1.0
const FLOOR_PENETRATION_EPS : float = 0.005
const WATCHDOG_WINDOW : float = 0.5
const WATCHDOG_REVERSALS : int = 4
const WATCHDOG_SPEED_EPS : float = 0.05
# Reversals only count as jitter while the piece is SLOW. A piece tumbling
# hard during the break (several m/s, reversing off floor and neighbour
# impacts) is legitimate motion; the band below is the low-amplitude
# oscillation the solver cannot settle out of.
const WATCHDOG_SPEED_MAX : float = 0.4
const WATCHDOG_LIFT_CLEARANCE : float = 0.25
const WATCHDOG_UNFREEZE_DELAY : float = 0.25
const WATCHDOG_REARM_DELAY : float = 0.5

var _pieces : Array[RigidBody3D] = []
var _settle_timer : Timer
var _elapsed : float = 0.0

# Watchdog per-piece state, index-aligned with _pieces.
var _prev_signs : Array[int] = []
var _reversal_times : Array = []
var _armed : Array[bool] = []
var _lifted_once : Array[bool] = []
var _unfreeze_at : Array[float] = []


func _ready():
	for child in get_children():
		var rb := child as RigidBody3D
		if rb != null:
			_pieces.append(rb)
	if _pieces.is_empty():
		return
	_prev_signs.resize(_pieces.size())
	_prev_signs.fill(0)
	_armed.resize(_pieces.size())
	_armed.fill(true)
	_lifted_once.resize(_pieces.size())
	_lifted_once.fill(false)
	_unfreeze_at.resize(_pieces.size())
	_unfreeze_at.fill(0.0)
	for i in _pieces.size():
		_reversal_times.append([])
	# Penetration sweeps: first after a short grace, then recurring so later
	# embeds are caught too. A piece resting ON the floor is left alone.
	_settle_timer = Timer.new()
	_settle_timer.name = "SettleLiftTimer"
	_settle_timer.wait_time = SETTLE_SWEEP_INTERVAL
	_settle_timer.timeout.connect(_on_SettleLiftTimer_timeout)
	add_child(_settle_timer)
	_settle_timer.start()


func _physics_process(delta):
	_elapsed += delta
	for i in _pieces.size():
		var piece := _pieces[i] as RigidBody3D
		if piece == null or not is_instance_valid(piece):
			continue
		_watchdog_step(i, piece)


func _watchdog_step(i : int, piece : RigidBody3D):
	# Release a frozen lifted piece back to the solver, then re-arm after a
	# short delay so the post-lift observation is a fresh window.
	if piece.freeze and _unfreeze_at[i] > 0.0 and _elapsed >= _unfreeze_at[i]:
		piece.freeze = false
		_unfreeze_at[i] = 0.0
		_armed[i] = false
		_prev_signs[i] = 0
		_reversal_times[i].clear()
		_unfreeze_at[i] = -(_elapsed + WATCHDOG_REARM_DELAY)   # negative marks re-arm time
		return
	if _unfreeze_at[i] < 0.0 and _elapsed >= -_unfreeze_at[i]:
		_unfreeze_at[i] = 0.0
		_armed[i] = true
	if not _armed[i]:
		return
	var velocity := piece.linear_velocity
	var speed := velocity.length()
	if speed < WATCHDOG_SPEED_EPS or speed > WATCHDOG_SPEED_MAX:
		# Too slow (resting or asleep) or too fast (legitimately energetic):
		# neither is jitter. A fast piece's sign memory resets so its first
		# in-band direction after settling does not read as a reversal.
		_prev_signs[i] = 0
		_reversal_times[i].clear()
		return
	# Dominant-axis reversal counting per the report design: track the sign
	# of the largest velocity component and time-stamp every sign flip.
	var dominant := 0
	var best := 0.0
	for axis in 3:
		var magnitude : float = absf(velocity[axis])
		if magnitude > best:
			best = magnitude
			dominant = axis
	var sign_value := signi(int(velocity[dominant] * 1000.0))
	if sign_value == 0:
		return
	if _prev_signs[i] != 0 and sign_value != _prev_signs[i]:
		_reversal_times[i].append(_elapsed)
	_prev_signs[i] = sign_value
	var cutoff : float = _elapsed - WATCHDOG_WINDOW
	while _reversal_times[i].size() > 0 and _reversal_times[i][0] < cutoff:
		_reversal_times[i].pop_front()
	if _reversal_times[i].size() >= WATCHDOG_REVERSALS:
		_watchdog_trigger(i, piece)


func _watchdog_trigger(i : int, piece : RigidBody3D):
	_armed[i] = false
	_reversal_times[i].clear()
	_prev_signs[i] = 0
	if not _lifted_once[i]:
		# First offense: freeze and lift the piece out above the floor so it
		# can drop back onto the surface instead of resting inside it.
		_lifted_once[i] = true
		piece.freeze = true
		piece.linear_velocity = Vector3.ZERO
		piece.angular_velocity = Vector3.ZERO
		var bottom := _piece_bottom_y(piece)
		if bottom == INF:
			# No measurable collision geometry: the piece cannot be lifted,
			# delete it (owner ruling: unliftable oscillators do not stay).
			_delete_piece(i, piece)
			return
		var lift := (FLOOR_TOP_Y + WATCHDOG_LIFT_CLEARANCE) - bottom
		if lift > 0.0:
			piece.global_position.y += lift
		_unfreeze_at[i] = _elapsed + WATCHDOG_UNFREEZE_DELAY
		return
	# Still oscillating after the lift-out: delete the piece. The shard is
	# never deleted (exemption idiom from pickable_item.gd).
	var script_global_name := ""
	if piece.get_script():
		script_global_name = piece.get_script().get_global_name()
	if script_global_name == "ShardOfTheComet":
		return
	_delete_piece(i, piece)


func _delete_piece(i : int, piece : RigidBody3D):
	push_warning("Watchdog: deleting oscillating broken-door piece '%s'" % piece.name)
	_pieces[i] = null
	piece.queue_free()


func _on_SettleLiftTimer_timeout():
	# Skip the very first tick only if it fires before the grace period ends
	if _elapsed < SETTLE_GRACE:
		return
	for piece in _pieces:
		if piece != null and is_instance_valid(piece):
			_settle_lift_piece(piece)


func _settle_lift_piece(piece : RigidBody3D):
	# Return the piece to the ground, do not destroy physics at rest: lift it
	# minimally so its collision bottom rests ON the floor surface instead of
	# partially inside the slab.
	var bottom := _piece_bottom_y(piece)
	if bottom == INF:
		return
	if bottom < FLOOR_TOP_Y - FLOOR_PENETRATION_EPS:
		piece.global_position.y += FLOOR_TOP_Y - bottom


func _piece_bottom_y(piece : RigidBody3D) -> float:
	# Lowest world Y over the piece's collision shapes. All pieces use
	# BoxShape3D approximations per the tscn; other shape types are skipped
	# rather than mis-measured.
	var bottom := INF
	for node in piece.find_children("", "CollisionShape3D", true, false):
		var collision_shape := node as CollisionShape3D
		if collision_shape == null or not (collision_shape.shape is BoxShape3D):
			continue
		var box := collision_shape.shape as BoxShape3D
		var aabb := AABB(-box.size * 0.5, box.size)
		var world_aabb := (collision_shape.global_transform * aabb)
		bottom = minf(bottom, world_aabb.position.y)
	return bottom


func apply_impulse(position : Vector3, impulse : Vector3, decay : float):
	for _rb in get_children():
		var rb : RigidBody3D = _rb as RigidBody3D
		if (not is_instance_valid(rb)):
			continue
		var offset : Vector3 = position - rb.global_position
		var distance : float = offset.length()
		var attenuation = 1.0/(1.0 + pow(distance, decay))
		rb.apply_impulse(impulse*attenuation, offset)
