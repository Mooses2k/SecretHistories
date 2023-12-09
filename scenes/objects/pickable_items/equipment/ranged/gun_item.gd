### Is a tool to support use in player_animations_test.gd
tool
class_name GunItem
extends EquipmentItem


signal target_hit(target, position, direction, normal)
signal on_shoot()

enum MeleeStyle {
	BUTT_STRIKE,
	PISTOL_WHIP,
	BAYONET,
	COUNT
}

export(Array, Resource) var ammo_types

export var ammunition_capacity = 0
export var reload_amount = 0
export var reload_time = 0.0
export var damage_offset = 0
export var dispersion_offset_degrees = 0
export var cooldown = 1.0
export var handling = 5.0

export var ads_hold_position : Vector3
export var ads_hold_rotation : Vector3
var ads_reset_position : Vector3
var ads_reset_rotation : Vector3


export var animation_reload_sequence : int 
export(MeleeStyle) var melee_style : int = 0
export (NodePath) var player_path

onready var player = get_node(player_path)

var current_ammo : int = 0
var current_ammo_type : Resource = null

#var is_reloading = false    # This has been changed to a character trait
var on_cooldown = false

var _queued_reload_type : Resource = null
var _queued_reload_amount : int = 0

export (NodePath) var detection_raycast
onready var raycast = get_node(detection_raycast)

func _ready():
#	print(get_parent().name)
#	if get_parent().name == "MainHandEquipmentRoot":
#		print("Transforming")
#		transform = get_hold_transform()
	ads_reset_position = hold_position.translation
	ads_reset_rotation = hold_position.rotation_degrees


func set_range(value : Vector2):
	var amount : int = value.x
	if value.y > value.x:
		amount += randi() % (int(1 + value.y - value.x))
	current_ammo = clamp(amount, 0, ammunition_capacity)
	current_ammo_type = ammo_types[0]


func shoot():
	print("shoot")
	var ammo_type = current_ammo_type as AmmunitionData

	# The reason it's MINUS damage_offset (thus louder) is more of the powder is exploding outside the barrel
	noise_level = ammo_type.damage - damage_offset   # damage_offset is a negative so this is a addition operation

	var max_dispersion_radians : float = deg2rad(dispersion_offset_degrees + ammo_type.dispersion) / 2.0
	var total_damage : int = damage_offset + ammo_type.damage

	var raycast_range = raycast.cast_to.length()
	raycast.clear_exceptions()
	raycast.add_exception(owner_character)
#	print("shoot")
	for pellet in ammo_type.pellet_count:
		var shoot_direction : Vector3 = Vector3.FORWARD.rotated(Vector3.RIGHT, randf() * max_dispersion_radians)
		shoot_direction = shoot_direction.rotated(Vector3.FORWARD, randf() * 2 * PI)
		raycast.cast_to = shoot_direction*raycast_range
		raycast.force_raycast_update()
		if raycast.is_colliding():
			var target = raycast.get_collider()
			var global_hit_position = raycast.get_collision_point()
			var global_hit_direction = raycast.global_transform.basis.xform(shoot_direction)
			var global_hit_normal = raycast.get_collision_normal()
			if target is Hitbox and target.owner.has_method("damage"):
				target.owner.damage(total_damage, ammo_type.attack_type, target)
			emit_signal("target_hit", target, global_hit_position, global_hit_direction, global_hit_normal)
	raycast.cast_to = Vector3.FORWARD * raycast_range
	current_ammo -= 1
	apply_knockback(total_damage)
	print(owner_character, " shoots a ", self)
	
	# Cultists can't recoil for now
	if owner_character.get_node("PlayerController"):
		owner_character.player_controller.current_control_mode.recoil(self, total_damage, handling)   # Should also send delta


func _use_primary():
	if (not owner_character.is_reloading) and (not on_cooldown) and current_ammo > 0:
		shoot()
		$CooldownTimer.start(cooldown)
		on_cooldown = true
		emit_signal("on_shoot")
	if (not owner_character.is_reloading) and (not on_cooldown) and current_ammo == 0:
		dryfire()


func dryfire():
	$Sounds/Dryfire.play()


func _use_reload():
	reload()


func _use_unload():
	unload()


# Needs more code for revolvers and bolt-actions as they're more complicated
func reload():
	if owner_character and current_ammo < ammunition_capacity and not owner_character.is_reloading:
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
					owner_character.is_reloading = true
					print(owner_character.animation_tree)
					reload_animation()
#					print(player.owner)
					# Eventually randomize which reload sound it uses
					$Sounds/Reload.play()
					return


func reload_animation():
	print(owner_character)
	if owner_character != null:
		print(owner_character.animation_tree)
		owner_character.animation_tree.set("parameters/AnimationState/current", 1)
		owner_character.animation_tree.set("parameters/Weapon_states/current", 3)
		owner_character.animation_tree.set("parameters/Reload_Animations/current", animation_reload_sequence )
		print(animation_reload_sequence)


# Holding R unloads the weapon, for instance if you want the ammo from it to then drop the weapon
func unload():
	if current_ammo > 0:
		$UnloadTimer.start(reload_time)
		owner_character.is_reloading = true
		
		# Later, based on parts of the reload animation
		$Sounds/Reload.play()
# TODO ALSO: generalize Sounds spatial etc to gun_item


#	TODO: Changing the status of the weapon (dropping the weapon or unequiping it)
# while one of these timers is active should appropriately reset the timer and deal any of it's side effects


func apply_knockback(total_damage):
	if raycast.is_colliding():
		var object_detected = raycast.get_collider()
		if object_detected is RigidBody and has_method("apply_damage") :
			print("detected rigidbody")
			object_detected.apply_central_impulse(-player.global_transform.basis.z * total_damage * 5)


func _on_ReloadTimer_timeout() -> void:
	if owner_character and owner_character.is_reloading and (current_ammo_type == null or current_ammo_type == _queued_reload_type):
		var inventory = owner_character.inventory
		if inventory.tiny_items.has(_queued_reload_type) and inventory.tiny_items[_queued_reload_type] >= _queued_reload_amount:
			var _reload_amount = min(_queued_reload_amount, reload_amount - current_ammo)
			inventory.remove_tiny_item(_queued_reload_type, _reload_amount)
			current_ammo_type = _queued_reload_type
			current_ammo += _reload_amount
	owner_character.is_reloading = false
	print("Reload done, reloaded ", _queued_reload_amount, " bullets")


func _on_UnloadTimer_timeout() -> void:
	if owner_character and owner_character.is_reloading:
		var inventory = owner_character.inventory
		inventory.insert_tiny_item(current_ammo_type, current_ammo)
		print("Unload rounds: ", current_ammo)
		current_ammo = 0
		owner_character.is_reloading = false
		$Sounds/Unload.play()


func _on_CooldownTimer_timeout() -> void:
	noise_level = 0   # Simple place to put this
	on_cooldown = false
