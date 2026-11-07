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

enum MeleeStyle {
	BUTT_STRIKE,
	PISTOL_WHIP,
	BAYONET,
	COUNT
}

@export var ammo_types : Array[Resource]# (Array, Resource)

@export var ammunition_capacity : int = 0
@export var reload_amount : int = 0
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

@export var detection_raycast : NodePath

@onready var raycast : RayCast3D = get_node(detection_raycast) as RayCast3D
@onready var animation_player = %AnimationPlayer
@onready var player = get_node(player_path)
@onready var mesh = get_node_or_null(mesh_path)


func _ready():
#	print(get_parent().name)
#	if get_parent().name == "MainHandEquipmentRoot":
#		print("Transforming")
#		transform = get_hold_transform()
	ads_reset_position = hold_position.position
	ads_reset_rotation = hold_position.rotation_degrees
	get_reload_length()

	if owner_character:   # start loaded, for now
		reload()


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
	if animation_player:
		reload_time = animation_player.get_animation("reload").length - 0.3


func set_range(value : Vector2):
	var amount : int = value.x
	if value.y > value.x:
		amount += randi() % (int(1 + value.y - value.x))
	current_ammo = clamp(amount, 0, ammunition_capacity)
	if not ammo_types.is_empty():
		current_ammo_type = ammo_types[0]


func shoot():
	var ammo_type = current_ammo_type as AmmunitionData

	# The reason it's MINUS damage_offset (thus louder) is more of the powder is exploding outside the barrel
	noise_level = ammo_type.damage - damage_offset   # damage_offset is a negative so this is a addition operation

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
	if (not owner_character.state.is_reloading) and (not on_cooldown) and current_ammo > 0:
		shoot()
		$CooldownTimer.start(cooldown)
		on_cooldown = true
		emit_signal("on_shoot")
	if (not owner_character.state.is_reloading) and (not on_cooldown) and current_ammo == 0:
		dryfire()


func dryfire():
	$Sounds/Dryfire.play()


func _use_reload():
	reload()


func _use_unload():
	#unload()   # TODO: when animations available for unload, remove this line
	pass


# TODO: Needs more code for revolvers and bolt-actions as they're more complicated
# TODO: Needs some camera movement for immersion
func reload():
	if owner_character and current_ammo < ammunition_capacity and not owner_character.state.is_reloading:
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
					$ReloadTimer.start(reload_time)
					_queued_reload_amount = _reload_amount
					_queued_reload_type = ammo_type
					owner_character.state.is_reloading = true
					owner_character.state.reloading_item = self
					##This is responsible for the reload animations for player
					#if "Player" in owner_character.name:
						#owner_character.player_animations.reload_weapons()
#					elif "Cultist" in owner_character.name:
#						owner_character.reload_weapons()
#					print(player.owner)
					# TODO: Eventually randomize which reload sound it uses
					$Sounds/Reload.play()
					noise_level = 8
					return


# Holding R unloads the weapon, for instance if you want the ammo from it to then drop the weapon
func unload():
	if current_ammo > 0:
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
	# owner_character dereference kept inside the guard (Brooks audit 4.6):
	# the is_reloading reset used to run outside the guard and errored when the
	# gun was dropped mid-reload and owner_character became invalid.
	if owner_character and owner_character.state.is_reloading:
		if current_ammo_type == null or current_ammo_type == _queued_reload_type:
			var inventory = owner_character.inventory
			if inventory.tiny_items.has(_queued_reload_type) and inventory.tiny_items[_queued_reload_type] >= _queued_reload_amount:
				# The queued amount is already stage-sized (reload() clamped it
				# against reload_amount, tiny supply, and free capacity). The
				# boundary re-clamp is a capacity guard only: clamping against
				# reload_amount - current_ammo here silently loaded zero rounds
				# whenever a weapon held at least reload_amount rounds already
				# (dormant while every weapon shipped reload_amount == capacity).
				var _reload_amount = min(_queued_reload_amount, ammunition_capacity - current_ammo)
				inventory.remove_tiny_item(_queued_reload_type, _reload_amount)
				current_ammo_type = _queued_reload_type
				current_ammo += _reload_amount
		owner_character.state.is_reloading = false
		if owner_character.state.reloading_item == self:
			owner_character.state.reloading_item = null
		reload_stage_finished.emit(current_ammo)


## A mainhand slot switch during a reload requests this abort. Every reload
## stage in this codebase is a single ReloadTimer whose rounds all land at
## the timeout (the webley queues all 6 rounds in one timer, the lee-metford
## one round per key press), so letting the in-flight stage run out would
## finish the whole reload. The abort therefore preempts the timer: the
## queued rounds are not consumed (the inventory is only debited at the
## timeout) and the rounds loaded before the stage stand. An ammo-type
## switch staged in reload() already returned the old rounds to the
## inventory, so nothing is lost there either.
func request_reload_abort() -> void:
	if $ReloadTimer.is_stopped():
		return
	$ReloadTimer.stop()
	if owner_character and owner_character.state.is_reloading:
		owner_character.state.is_reloading = false
		if owner_character.state.reloading_item == self:
			owner_character.state.reloading_item = null
	$Sounds/Reload.stop()


func _on_UnloadTimer_timeout() -> void:
	if owner_character and owner_character.state.is_reloading:
		var inventory = owner_character.inventory
		inventory.insert_tiny_item(current_ammo_type, current_ammo)
		current_ammo = 0
		owner_character.state.is_reloading = false
		$Sounds/Unload.play()


func _on_CooldownTimer_timeout() -> void:
	noise_level = 0   # Simple place to put this
	on_cooldown = false
