@tool
### Is a tool to support use in player_animations_test.gd
class_name GunItem
extends EquipmentItem


signal target_hit(target, position, direction, normal)
signal on_shoot()

# Emitted when a reload stage completes: the stage's rounds are already
# applied at this point. An abort request preempts the stage instead and
# does not emit this signal.
signal reload_stage_finished(loaded_amount : int)

# Emitted when an abort's close beat finishes and the reload state fully
# clears (after the close animation, not at the press of the abort). The
# character-side reload coordinator uses it to time the offhand re-equip so
# the swap waits out the close beat (owner rule, research doc 6.1).
signal reload_aborted()

enum MeleeStyle {
	BUTT_STRIKE,
	PISTOL_WHIP,
	BAYONET,
	COUNT
}

## Cadence window for the derived per-round reload quantum: a mis-authored
## clip must not produce absurd click spacing.
const MIN_STAGED_CYCLE_TIME : float = 0.3
const MAX_STAGED_CYCLE_TIME : float = 3.0

@export var ammo_types : Array[Resource]# (Array, Resource)

@export var ammunition_capacity : int = 0
@export var reload_amount : int = 0
## Per-round reload clicks: one stream per landed staged round, indexed by
## landing order, the last entry covering any further rounds. Guns without
## entries keep their per-round cycles silent behind the press composite.
@export var per_chamber_sounds : Array[AudioStream] = []
## Per-gun reload shell effect node (a GunShellEffects script): owns the
## casing data for the press-time ejection beat. Empty for guns that never
## eject (Lee-Metford and Martini-Henry rifle carried no shell effects in
## 3.x).
@export var shell_effects_path : NodePath
## Library clip that plays as the abort close beat (the action swinging
## shut) when this press is interrupted. Empty means tail mode: the close
## segment is the composite's final stretch, started at reload_close_start.
@export var reload_close_clip : StringName = &""
## Composite time where the close segment starts (tail mode only). Derived
## from the wired composite's action-bone keys: webley 7.4, khyber 1.6667,
## both shotguns 3.3. Guns with a dedicated close clip leave this at 0.
@export var reload_close_start : float = 0.0
@export var damage_offset : int = 0
@export var dispersion_offset_degrees : int = 0
@export var cooldown : float = 1.0
@export var handling : float = 5.0

@export var reload_position : Vector3
@export var reload_rotation : Vector3

@export var ads_hold_position : Vector3
@export var ads_hold_rotation : Vector3

@export var melee_style: MeleeStyle = 0
@export var player_path: NodePath
@export var mesh_path: NodePath

var max_raycast_correction_angle_degrees : float = 45

var ads_reset_position : Vector3
var ads_reset_rotation : Vector3
var mesh_reset_position : Vector3 = Vector3(0, 0, 0)
var reload_time : float = 0.0
var current_ammo : int = 0:
	set(value):
		current_ammo = value
		item_data_changed.emit()
var current_ammo_type : Resource = null

#var is_reloading = false    # This has been changed to a character trait
var on_cooldown = false

var _queued_reload_type : Resource = null
var _queued_reload_amount : int = 0
## Rounds of the staged reload that have not landed yet. One press stages up
## to reload_amount rounds (owner ruling: the webley loads one round at a
## time up to 6 with ONE press), and each ReloadTimer cycle lands exactly
## one of them with its per-chamber sound until the stage is done.
var _staged_reload_remaining : int = 0
## Rounds of the staged batch that have landed so far; indexes the
## per-chamber sound list.
var _staged_rounds_landed : int = 0
## Per-press reload quantum: the weapon reload clip length divided by the
## rounds this press stages (owner decision: one press lasts about as long
## as the authored animation and the rounds spread across it), clamped to
## MIN/MAX_STAGED_CYCLE_TIME. Falls back to reload_time when no reload clip
## is resolvable. Cached at press time so the chain cycles reuse it.
var _staged_cycle_time : float = 0.0
## Set at unload press: realistic ejection already dropped the chambers'
## contents into the world, so the unload boundary must not also return the
## rounds to the inventory.
var _unload_ejected : bool = false
## True while the close beat (action swinging shut) owns the ReloadTimer.
## The reload state stays set through it: the inventory lock and the parked
## slot switch both wait until the close beat ends (owner rule, research
## doc 6.1: the cylinder closes FIRST, then the swap runs).
var _close_beat_pending : bool = false
## Which ending the pending close beat finalizes: an abort (emits
## reload_aborted) or a natural stage completion (emits
## reload_stage_finished).
var _close_finish_aborts : bool = false
## True from the press that started the weapon reload composite until the
## reload fully ends. The close beat only plays for a press that actually
## opened the action: the ready-time convenience load (reload(false)) and
## an unload stay silent.
var _reload_composite_started : bool = false

@export var detection_raycast : NodePath

@onready var raycast : RayCast3D = get_node(detection_raycast) as RayCast3D
@onready var animation_player = %AnimationPlayer
@onready var player = get_node(player_path)
@onready var mesh = get_node_or_null(mesh_path)
@onready var _chamber_sound : AudioStreamPlayer3D = get_node_or_null("Sounds/Chamber") as AudioStreamPlayer3D
@onready var _shell_effects : Node = _resolve_shell_effects()


func _resolve_shell_effects() -> Node:
	if shell_effects_path.is_empty():
		return null
	return get_node_or_null(shell_effects_path)


func _ready():
#	print(get_parent().name)
#	if get_parent().name == "MainHandEquipmentRoot":
#		print("Transforming")
#		transform = get_hold_transform()
	ads_reset_position = hold_position.position
	ads_reset_rotation = hold_position.rotation_degrees
	get_reload_length()

	if owner_character:   # start loaded, for now
		# The ready-time convenience load is not a player press: no ejection
		# beat, the chamber never held spent cases.
		reload(false)


#TODO move this out of here
func _physics_process(delta):
	super._physics_process(delta)
	if Engine.is_editor_hint() or item_state != GlobalConsts.ItemState.EQUIPPED:
		return
	if (not is_instance_valid(owner_character)) or (not "state" in owner_character):
		return
	if owner_character.is_in_group("PLAYER"):
		return
	var owner_state : CharacterState = owner_character.state as CharacterState
	if not is_instance_valid(owner_state):
		return
	var target = owner_state.target
	var target_object : Node3D
	if not is_instance_valid(target):
		return
	if target is Node3D:
		target_object = target
	elif "object" in target:
		target_object = target.object as Node3D

	if not is_instance_valid(target_object):
		return
	var target_position_global = target_object.global_position + Vector3.UP * 0.5 # for 0.5 meters from ground
	var local_position = self.global_position
	var target_position : Vector3 = to_local(target_position_global)
	var delta_angle = Vector3.FORWARD.angle_to(target_position)
	if delta_angle > deg_to_rad(max_raycast_correction_angle_degrees):
		return
	raycast.look_at(target_position_global, Vector3.UP)


func get_reload_length():
	var anim_player := animation_player as AnimationPlayer
	if anim_player == null or not anim_player.has_animation("reload"):
		return
	reload_time = anim_player.get_animation("reload").length - 0.3


## One staged-reload timer cycle lasts the weapon's authored reload clip
## divided by the rounds this press stages, so the rounds spread across the
## clip (owner decision: one press lasts about as long as the authored
## animation). Without a resolvable reload clip the press falls back to
## reload_time per cycle, which keeps the per-round cadence of
## reload_amount == 1 guns unchanged. The result is clamped so a
## mis-authored clip cannot produce an absurd cadence.
func _staged_reload_cycle_time(round_count : int) -> float:
	if round_count <= 0:
		return reload_time
	var anim_player := animation_player as AnimationPlayer
	if anim_player == null or not anim_player.has_animation("reload"):
		return reload_time
	var clip_length : float = anim_player.get_animation("reload").length
	if clip_length <= 0.0:
		return reload_time
	return clampf(clip_length / float(round_count), MIN_STAGED_CYCLE_TIME, MAX_STAGED_CYCLE_TIME)


## One per-chamber click per landed round when the gun wires a
## Sounds/Chamber player and a stream list; otherwise the per-round cycles
## are silent (the press composite carries the swing-open feel until the
## reload clips are split per phase).
func _play_chamber_sound() -> void:
	if _chamber_sound == null or per_chamber_sounds.is_empty():
		return
	_chamber_sound.stream = per_chamber_sounds[clampi(_staged_rounds_landed - 1, 0, per_chamber_sounds.size() - 1)]
	_chamber_sound.play()


## Owner-approved gunshot noise formula A: linear mapping chosen for gameplay
## texture, one noise step per two damage points, so every gun stays distinct
## without extremes. Pellet ammo measures its total payload (the shell's
## damage times the pellet count) so a louder report tracks the powder
## actually burned. The physically faithful model would be a pure log10
## mapping (noise proportional to sound power, about 10 * log10 of the
## muzzle energy); that is a documented future option. The barrel-shortness
## modifier applies AFTER the transform: damage_offset is negative for
## shortened barrels, so subtracting it adds noise.
static func gunshot_noise_for(ammo_type : AmmunitionData, offset : int) -> float:
	var payload_damage : int = ammo_type.damage
	if ammo_type.pellet_count > 1:
		payload_damage = ammo_type.damage * ammo_type.pellet_count
	return 30.0 + round(payload_damage / 2.0) - offset


func set_range(value : Vector2):
	var amount : int = value.x
	if value.y > value.x:
		amount += randi() % (int(1 + value.y - value.x))
	current_ammo = clamp(amount, 0, ammunition_capacity)
	if not ammo_types.is_empty():
		current_ammo_type = ammo_types[0]


func shoot():
	var ammo_type = current_ammo_type as AmmunitionData

	noise_level = gunshot_noise_for(ammo_type, damage_offset)

	var max_dispersion_radians : float = deg_to_rad(dispersion_offset_degrees + ammo_type.dispersion) / 2.0
	var total_damage : int = damage_offset + ammo_type.damage

	var raycast_range = raycast.target_position.length()
	raycast.clear_exceptions()
	raycast.add_exception(owner_character)
	# A shot can never damage its own shooter: the exception above covers the
	# character body only, while the Hurtbox sensors are separate Area3D
	# children (separate collision objects RayCast3D does not inherit
	# exceptions from). A muzzle ray that crosses the shooter's own hand or
	# torso hurtbox capsule would otherwise feed the shooter their own bullet
	# damage and knock their rig out (KNOCKED_OUT ragdoll: held items drop to
	# the floor with the bones and movement locks until the timer recovers).
	for hurtbox in owner_character.find_children("*", "Hurtbox", true, false):
		raycast.add_exception(hurtbox)
	# Per-collider pellet accumulation: pellets that hit the same target are
	# applied as one summed damage call instead of one call per pellet.
	var hit_accumulator : Dictionary = Dictionary()
	for pellet in ammo_type.pellet_count:
		var shoot_direction : Vector3 = Vector3.FORWARD.rotated(Vector3.RIGHT, randf() * max_dispersion_radians)
		shoot_direction = shoot_direction.rotated(Vector3.FORWARD, randf() * 2 * PI)
		raycast.target_position = shoot_direction*raycast_range
		raycast.force_raycast_update()
		if raycast.is_colliding():
			var target = raycast.get_collider()
			var global_hit_position = raycast.get_collision_point()
			# normalized: the raycast inherits the hand attachment scale, which
			# would shrink the direction used for the door break impulse
			var global_hit_direction = (raycast.global_transform.basis * (shoot_direction)).normalized()
			var global_hit_normal = raycast.get_collision_normal()
			if hit_accumulator.has(target):
				hit_accumulator[target].damage += total_damage
				hit_accumulator[target].hit_position = global_hit_position
				hit_accumulator[target].hit_direction = global_hit_direction
			else:
				hit_accumulator[target] = {"damage": total_damage, "attack_type": ammo_type.attack_type, "hit_position": global_hit_position, "hit_direction": global_hit_direction}
			emit_signal("target_hit", target, global_hit_position, global_hit_direction, global_hit_normal)
	raycast.target_position = Vector3.FORWARD * raycast_range
	for target in hit_accumulator:
		if target is Hurtbox:# or target.owner.has_method("damage"):
			var hit = hit_accumulator[target]
			target.damage(hit.damage, hit.attack_type, hit.hit_direction, hit.hit_position)
	current_ammo -= 1
	apply_knockback(total_damage)

	# Cultists can't recoil for now
	if owner_character.get_node_or_null("PlayerController"):
		#owner_character.recoil(self, total_damage, handling)   # Should also send delta
		owner_character.recoil()


func _use_primary():
	var ammo_type := current_ammo_type as AmmunitionData
	if (not owner_character.state.is_reloading) and (not on_cooldown) and current_ammo > 0:
		shoot()
		$CooldownTimer.start(cooldown)
		on_cooldown = true
		emit_signal("on_shoot")
		# No tinnitus here: the owner removed the gunfire ringing (the white
		# screen flash read as a broken overlay). Tinnitus is the 3.x
		# ghost-attack effect family; its only producer is the ghost damage
		# area (docs/research/ui-parity-trio.md section 1). The noise_level
		# set in shoot() stays: that is the AI hearing channel.
	if (not owner_character.state.is_reloading) and (not on_cooldown) and current_ammo == 0:
		dryfire()


func dryfire():
	$Sounds/Dryfire.play()


func _use_reload():
	reload()


func _use_unload():
	#unload()   # TODO: when animations available for unload, remove this line
	pass


## The ejection mode at press time (a mid-game settings change applies from
## the next press on). Read through the GameSettings null-safe gate so
## headless and editor runs never touch a missing registration.
func _realistic_shell_ejection() -> bool:
	if Engine.is_editor_hint():
		return false
	return GameSettings.realistic_shell_ejection_enabled()


## A press opens the action: the chambers empty per the "Realistic Shell
## Ejection" setting, read at press time. OFF (arcade, default): only the
## spent chambers eject, capacity - live_rounds casings, and the live rounds
## stay chambered through the reload. ON (realistic): the action empties
## like a real ejector rod run, all chambers at once: the spent chambers
## leave their casings and each unfired round lands in the world as its
## loose-ammo pickup item (Receiver rule, issue #644 bullet 4), so the total
## ejected items equal the capacity. Unspent rounds are never returned to
## inventory by an ejection: they are grabbable world pickups. The per-gun
## shell effect node owns both the casing and the loose round scenes; guns
## without shell wiring stay silent in both modes (Lee-Metford and
## Martini-Henry rifle).
func _eject_chambers(live_rounds : int) -> void:
	if _shell_effects == null or not _shell_effects.has_method("expell_shells"):
		return
	var world_parent := _casing_world_parent()
	var spent_cases := ammunition_capacity - live_rounds
	if spent_cases > 0:
		_shell_effects.call("expell_shells", spent_cases, world_parent)
	if _realistic_shell_ejection() and live_rounds > 0 and _shell_effects.has_method("expell_live_rounds"):
		_shell_effects.call("expell_live_rounds", live_rounds, world_parent)


## The landed round's insertion visual rides the chamber click (3.x drove
## this from weapon-clip method tracks; the port dropped those, so the beat
## is code-driven per staged cycle: a live round appears in the left hand's
## shell slot and the cylinder slot for that chamber fills). Visual only:
## the staged chain already debited the round from the inventory. The
## timing is approximate by design (rounds spread across the composite by
## the per-press quantum, no frame-perfect chase of the authored mid-clip
## moments). Only a press that opened the action inserts visuals: the
## ready-time convenience load stays silent.
func _insert_landed_round_visual() -> void:
	if not _reload_composite_started:
		return
	if _shell_effects == null or not _shell_effects.has_method("insert_landed_round"):
		return
	_shell_effects.call("insert_landed_round")


func _casing_world_parent() -> Node:
	if is_instance_valid(GameManager.game):
		return GameManager.game
	return get_tree().current_scene


# TODO: Needs more code for revolvers and bolt-actions as they're more complicated
# TODO: Needs some camera movement for immersion
func reload(eject_spent_casings : bool = true) -> void:
	if owner_character and current_ammo < ammunition_capacity and not owner_character.state.is_reloading:
		# Captured before the staging loop: an ammo-type switch would zero
		# current_ammo, and the ejection counts must reflect the cylinder as
		# it stood at the press.
		var live_rounds_to_eject := current_ammo
		var inventory = owner_character.inventory
		for ammo_type in ammo_types:
			if inventory.tiny_items.has(ammo_type) and inventory.tiny_items[ammo_type] > 0:
				if ammo_type != current_ammo_type:
					if current_ammo_type != null:
						if not inventory.tiny_items.has(current_ammo_type):
							inventory.tiny_items[current_ammo_type] = 0
						inventory.tiny_items[current_ammo_type] += current_ammo
					current_ammo = 0
					current_ammo_type = null
				var _reload_amount = min(inventory.tiny_items[ammo_type], min(reload_amount, ammunition_capacity - current_ammo))
				if _reload_amount > 0:
					_staged_cycle_time = _staged_reload_cycle_time(_reload_amount)
					_staged_rounds_landed = 0
					if eject_spent_casings:
						_eject_chambers(live_rounds_to_eject)
						_start_reload_composite()
						# Phase 2: the character-side reload layer rides the
						# same press (the 3.x player hook, rebuilt on the
						# humanoid base with a class check, no name-string
						# checks). The coordinator handles the small-gun
						# offhand unequip/re-equip and the tree OneShot.
						var character := owner_character as HumanoidCharacter
						if character != null:
							character.play_reload_animation(self)
					$ReloadTimer.start(_staged_cycle_time)
					_queued_reload_amount = _reload_amount
					_staged_reload_remaining = _reload_amount
					_queued_reload_type = ammo_type
					owner_character.state.is_reloading = true
					owner_character.state.reloading_item = self
					# TODO: Eventually randomize which reload sound it uses
					$Sounds/Reload.play()
					noise_level = 8
					return


## Starts the weapon-local reload composite on the gun's own AnimationPlayer
## (the 3.x weapon-side animation: break open, insertion beats, action
## closing). The staged rounds spread across the composite via the per-press
## quantum, so one insertion beat per landed round is approximate, not
## frame-perfect. Only a real press plays it; the ready-time convenience
## load (reload(false)) must not animate a gun that is not in hand yet.
func _start_reload_composite() -> void:
	var anim_player := animation_player as AnimationPlayer
	if anim_player == null or not anim_player.has_animation("reload"):
		return
	anim_player.stop()
	anim_player.play("reload")
	_reload_composite_started = true


## Close-beat wait in seconds for an interruption or a clamped completion:
## the dedicated close clip's length, or the composite tail from
## reload_close_start. Returns the remaining close time when the composite
## is already inside its close segment (never restart a close that is
## playing), and 0.0 when nothing is authored to play.
func _close_beat_time(anim_player : AnimationPlayer) -> float:
	if anim_player == null:
		return 0.0
	var reload_length : float = 0.0
	var has_reload := anim_player.has_animation("reload")
	if has_reload:
		reload_length = anim_player.get_animation("reload").length
	if reload_close_clip != &"" and anim_player.has_animation(reload_close_clip):
		var clip_length : float = anim_player.get_animation(reload_close_clip).length
		if has_reload and _reload_composite_started and _is_composite_playing(anim_player):
			var close_start := reload_length - clip_length
			if anim_player.current_animation_position >= close_start:
				return maxf(reload_length - anim_player.current_animation_position, 0.0)
		return clip_length
	if has_reload and reload_close_start > 0.0 and reload_close_start < reload_length:
		if _reload_composite_started and _is_composite_playing(anim_player) \
				and anim_player.current_animation_position >= reload_close_start:
			return maxf(reload_length - anim_player.current_animation_position, 0.0)
		return reload_length - reload_close_start
	return 0.0


func _is_composite_playing(anim_player : AnimationPlayer) -> bool:
	return anim_player.is_playing() and anim_player.current_animation == "reload"


## Plays the close beat before the reload state clears. An abort always
## closes the action first (owner rule, research doc 6.1: the cylinder
## closes FIRST, then the swap runs) when this press actually started the
## composite. A natural completion only needs it when the staged quantum
## finished ahead of the composite (the clamped single-round guns: the
## Lee-Metford press lands its round at 3.0 s while the authored clip runs
## 11.4 s, so the bolt cuts to its close beat instead of animating 8 s of
## orphaned insertion). While the beat plays, is_reloading stays set: the
## inventory lock holds, shooting stays blocked, and a parked slot switch
## waits until the beat ends.
func _begin_close_beat(aborting : bool) -> void:
	var close_time := 0.0
	var anim_player := animation_player as AnimationPlayer
	if aborting:
		if _reload_composite_started:
			close_time = _close_beat_time(anim_player)
	elif _is_composite_playing(anim_player):
		close_time = _close_beat_time(anim_player)
	if close_time <= 0.0:
		_finalize_reload(aborting)
		return
	_close_beat_pending = true
	_close_finish_aborts = aborting
	if anim_player != null:
		anim_player.stop()
		if reload_close_clip != &"" and anim_player.has_animation(reload_close_clip):
			anim_player.play(reload_close_clip)
		elif anim_player.has_animation("reload"):
			anim_player.play("reload")
			anim_player.seek(reload_close_start, true)
	$ReloadTimer.start(close_time)


func _finish_close_beat() -> void:
	_close_beat_pending = false
	_finalize_reload(_close_finish_aborts)


## Ends the reload: clears the character reload state (guarded: the gun can
## be dropped mid-close and its owner freed) and emits the matching signal.
func _finalize_reload(aborting : bool) -> void:
	_reload_composite_started = false
	# The insertion visuals clear with the close beat's end: an abort wipes
	# the pending and inserted visuals alike, a natural completion empties
	# the dressing slots the way the 3.x clear_all_slots beat did.
	if _shell_effects != null and _shell_effects.has_method("clear_insertion_visuals"):
		_shell_effects.call("clear_insertion_visuals")
	if is_instance_valid(owner_character) and owner_character.state.is_reloading:
		owner_character.state.is_reloading = false
		if owner_character.state.reloading_item == self:
			owner_character.state.reloading_item = null
	if aborting:
		reload_aborted.emit()
	else:
		reload_stage_finished.emit(current_ammo)


# Holding R unloads the weapon, for instance if you want the ammo from it to then drop the weapon
func unload():
	if current_ammo > 0:
		# Realistic ejection: the unload press opens the action too, so the
		# chambers empty into the world (the spent chambers leave their
		# casings, the live rounds land as loose pickups) and the boundary
		# below must not also return them to the inventory. Arcade mode
		# keeps the quiet return.
		_unload_ejected = _realistic_shell_ejection()
		if _unload_ejected:
			_eject_chambers(current_ammo)
		$UnloadTimer.start(reload_time)
		owner_character.state.is_reloading = true
		# Unload is NOT a reload: reloading_item stays null, so the inventory
		# keeps hard-blocking slot switches while an unload is in flight.
		owner_character.state.reloading_item = null

		# Later, based on parts of the reload animation
		$Sounds/Reload.play()
		noise_level = 8
# TODO ALSO: generalize Sounds spatial etc to gun_item


#	TODO: Changing the status of the weapon (dropping the weapon or unequiping it)
# while one of these timers is active should appropriately reset the timer and deal any of it's side effects


func apply_knockback(total_damage):
	if raycast.is_colliding():
		var object_detected = raycast.get_collider()
		if object_detected is RigidBody3D and object_detected.has_method("apply_damage") :
			object_detected.apply_central_impulse(-self.global_transform.basis.z * total_damage * 5)


func _on_ReloadTimer_timeout() -> void:
	# A pending close beat owns this timeout: it is the beat's end marker.
	if _close_beat_pending:
		_finish_close_beat()
		return
	# owner_character dereference kept inside the guard (Brooks audit 4.6):
	# the is_reloading reset used to run outside the guard and errored when the
	# gun was dropped mid-reload and owner_character became invalid.
	if owner_character and owner_character.state.is_reloading:
		if current_ammo_type == null or current_ammo_type == _queued_reload_type:
			var inventory = owner_character.inventory
			# One round per timer cycle (owner ruling: one press loads up to
			# reload_amount rounds ONE at a time, each with its per-chamber
			# sound). Each landed round is debited immediately, so an abort
			# keeps exactly the rounds already inserted.
			if _staged_reload_remaining > 0 and inventory.tiny_items.has(_queued_reload_type) and inventory.tiny_items[_queued_reload_type] >= 1:
				inventory.remove_tiny_item(_queued_reload_type, 1)
				current_ammo_type = _queued_reload_type
				current_ammo += 1
				_staged_reload_remaining -= 1
				_staged_rounds_landed += 1
				_play_chamber_sound()
				_insert_landed_round_visual()
				if _staged_reload_remaining > 0 and current_ammo < ammunition_capacity and inventory.tiny_item_amount(_queued_reload_type) > 0:
					# The chain cycles on the cached per-press quantum. The
					# composite Reload sound is NOT replayed per round: it
					# played once at the press and the per-chamber click
					# above carries the landing.
					$ReloadTimer.start(_staged_cycle_time)
					return
		# Last round of the stage (or nothing left to land): close the action
		# beat first when the composite is still short of its close segment,
		# then clear the state and report the stage.
		_begin_close_beat(false)


## A mainhand slot switch during a reload requests this abort. A staged
## reload lands one round per ReloadTimer cycle (each debited as it lands),
## so the abort preempts the remaining rounds: the rounds already inserted
## stand, the rest stay in the inventory. The character reload state does
## NOT clear here: the close beat plays first (owner rule, research doc
## 6.1: the cylinder closes FIRST, then the swap runs), and
## _finalize_reload clears the state when the beat ends, which is when a
## parked slot switch may run. An ammo-type switch staged in reload()
## already returned the old rounds to the inventory, so nothing is lost
## there either.
func request_reload_abort() -> void:
	# A close beat already owns the finish; a second abort must not restart
	# it or cut it short.
	if _close_beat_pending:
		return
	if $ReloadTimer.is_stopped():
		return
	$ReloadTimer.stop()
	if _chamber_sound != null:
		_chamber_sound.stop()
	$Sounds/Reload.stop()
	_begin_close_beat(true)


func _on_UnloadTimer_timeout() -> void:
	if owner_character and owner_character.state.is_reloading:
		var inventory = owner_character.inventory
		if not _unload_ejected:
			inventory.insert_tiny_item(current_ammo_type, current_ammo)
		_unload_ejected = false
		current_ammo = 0
		owner_character.state.is_reloading = false
		$Sounds/Unload.play()


func _on_CooldownTimer_timeout() -> void:
	noise_level = 0   # Simple place to put this
	on_cooldown = false
