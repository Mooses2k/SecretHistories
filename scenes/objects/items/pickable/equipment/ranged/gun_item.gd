extends EquipmentItem
class_name GunItem


enum MeleeStyle {
	BUTT_STRIKE,
	PISTOL_WHIP,
	BAYONET,
	COUNT
}

signal target_hit(target, position, direction, normal)
signal on_shoot()

export(Array, Resource) var ammo_types

export var ammunition_capacity = 0
export var reload_amount = 0
export var reload_time = 0.0
export var damage_offset = 0
export var dispersion_offset_degrees = 0
export var cooldown = 1.0

export(AttackTypes.Types) var melee_damage_type : int = 0
export(MeleeStyle) var melee_style : int = 0
export (NodePath) var player_path
onready var player = get_node(player_path)

var current_ammo : int = 0
var current_ammo_type : Resource = null

var is_reloading = false
var on_cooldown = false

var _queued_reload_type : Resource = null
var _queued_reload_amount : int = 0

export (NodePath) var detection_raycast

onready var raycast = get_node(detection_raycast)


func set_range(value : Vector2):
	var amount : int = value.x
	if value.y > value.x:
		amount += randi()%(int(1 + value.y - value.x))
	current_ammo = clamp(amount, 0, ammunition_capacity)
	current_ammo_type = ammo_types[0]


func shoot():
	print("shoot")
	var ammo_type = current_ammo_type as AmmunitionData
	var max_dispersion_radians : float = deg2rad(dispersion_offset_degrees + ammo_type.dispersion)/2.0
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
	raycast.cast_to = Vector3.FORWARD*raycast_range
	current_ammo -= 1
	apply_damage(total_damage)
#	if current_ammo == 0:
#		current_ammo_type = null


func _use_primary():
#	print("try use : ", is_reloading, " ", on_cooldown, " ", current_ammo)
	if (not is_reloading) and (not on_cooldown) and current_ammo > 0:
		shoot()
		$CooldownTimer.start(cooldown)
		on_cooldown = true
		emit_signal("on_shoot")


func _use_reload():
	reload()


func reload():
	if owner_character and current_ammo < ammunition_capacity and not is_reloading:
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
#					print("Reload queued")
					$ReloadTimer.start(reload_time)
					_queued_reload_amount = _reload_amount
					_queued_reload_type = ammo_type
					is_reloading = true
					GameManager.is_reloading = true
					return


#
#	TODO: Changing the status of the weapon (dropping the weapon or unequiping it)
# while one of these timers is active should appropriately reset the timer and deal any of it's side effects


func apply_damage(total_damage):
	if raycast.is_colliding():
		var object_detected=raycast.get_collider()
		if object_detected is RigidBody and has_method("apply_damage") :
			print("detected rigidbody")
			object_detected.apply_central_impulse(-player.global_transform.basis.z * total_damage * 5)


func _on_ReloadTimer_timeout() -> void:
	if owner_character and is_reloading and (current_ammo_type == null or current_ammo_type == _queued_reload_type):
		var inventory = owner_character.inventory
		if inventory.tiny_items.has(_queued_reload_type) and inventory.tiny_items[_queued_reload_type] >= _queued_reload_amount:
			var _reload_amount = min(_queued_reload_amount, reload_amount - current_ammo)
			inventory.remove_tiny_item(_queued_reload_type, reload_amount)
			current_ammo_type = _queued_reload_type
			current_ammo += reload_amount
	is_reloading = false
	GameManager.is_reloading = false
	print("Reload done, reloaded ", _queued_reload_amount, " bullets")


func _on_CooldownTimer_timeout() -> void:
	on_cooldown = false
	pass # Replace with function body.
