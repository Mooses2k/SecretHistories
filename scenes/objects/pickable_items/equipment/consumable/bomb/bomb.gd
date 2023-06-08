class_name BombItem
extends ConsumableItem


export var radius = 5 # meters
export var fragments = 200 # number of raycasts and/or particles
export var bomb_damage : float #amount of damage to be registered
export(AttackTypes.Types) var damage_type : int = 0

var countdown_started = false

onready var countdown_timer = $Countdown
onready var flash = $Flash


func _ready():
	print($Explosion.lifetime)


func _process(delta):
	if countdown_started == true:
		$Explosion.lifetime -= delta
	if $Explosion.lifetime < 1.2:
		queue_free()


func _use_primary():
	if countdown_timer.is_stopped():
		countdown_timer.start()
		$Fuse.emitting = true
	else:
		print("Trying to throw bomb")
		owner_character.drop_consumable(self)


func _on_Countdown_timeout():
	flash.get_node("FlashTimer").start()
	flash.visible = true
	$Effect.handle_sound()
	$Explosion.emitting = true
	$Shrapnel.emitting = true
	$Fuse.emitting = false
	$Mesh.visible = false
	$Explosion._on_Bomb_explosion()
	countdown_started = true
	# If it blows up in hand
	if owner_character.is_in_group("CHARACTER") and !item_state == GlobalConsts.ItemState.DROPPED:
		print("Bomb blew up in ", owner_character, "'s hand for ", fragments / 4 * bomb_damage, " damage.")
		owner_character.damage(fragments / 4 * bomb_damage, damage_type, owner_character)
		owner_character.drop_consumable(self)
	
	# Camera shake, untested
	if owner_character.is_in_group("PLAYER") and $Explosion/BlastRadius.get_overlapping_bodies(owner_character):
		owner_character.fps_camera.add_stress(0.5)   # Eventually maybe based on distance from explosion


func _on_FlashTimer_timeout():
	flash.visible = false
