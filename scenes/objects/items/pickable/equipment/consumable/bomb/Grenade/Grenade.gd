extends BombItem
class_name Grenade


onready var countdown_timer = $Countdown
var countdown_started = false


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
		get_parent().get_parent().get_parent().drop_consumable(self)
		pass


func _on_Countdown_timeout():
	$Explosion.emitting = true
	$Shrapnel.emitting = true
	$Fuse.emitting = false
	$SM_FrenchGrenade.visible = false
	countdown_started = true
