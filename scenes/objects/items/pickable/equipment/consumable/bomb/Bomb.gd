extends ConsumableItem
class_name BombItem


export var radius = 5
export var fragments = 200

var countdown_started = false

onready var countdown_timer = $Countdown


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
	$Mesh.visible = false
	GameManager.game.player.inventory.drop_primary_item()
	GameManager.game.player.inventory.drop_secondary_item()
	countdown_started = true
