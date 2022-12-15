extends ConsumableItem
class_name BombItem


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
		get_parent().get_parent().drop_consumable(self)
		pass


func _on_Countdown_timeout():
	flash.visible = true
	flash.get_node("FlashTimer").start()
	$Effect.handle_sound()
	$Explosion.emitting = true
	$Shrapnel.emitting = true
	$Fuse.emitting = false
	$Mesh.visible = false
	$Explosion._on_Bomb_explosion()
	countdown_started = true
	# below lines fix crash if bomb is still in hands when explodes
	if get_parent().get_parent().get_parent().is_in_group("CHARACTER"):
		get_parent().get_parent().get_parent().damage(bomb_damage, damage_type, get_parent().get_parent().get_parent())
		get_parent().get_parent().get_parent().drop_consumable(self)


# this doesn't work - it doesn't timeout until apparently the queue_free
func _on_FlashTimer_timeout():
	flash.visible = false
