extends ToolItem


var has_ever_been_on = false 
var is_lit = true

onready var firelight = $FireOrigin/Fire/Light
onready var durable_timer = $Durability


func _ready():
	durable_timer.start()


func _process(delta):
	if is_lit == true:
		durable_timer.pause_mode = false
	else:
		durable_timer.pause_mode = true
	if self.mode == equipped_mode and has_ever_been_on == false:
			durable_timer.start()
			has_ever_been_on = true
			firelight.visible = not firelight.visible
			$AnimationPlayer.play("flicker")
			$FireOrigin/Fire.emitting = not $FireOrigin/Fire.emitting
#			$MeshInstance.cast_shadow = not $MeshInstance.cast_shadow
			is_lit = true
	else:
		is_lit = false


func _use_primary():
	if !durable_timer.is_stopped():
		$FireOrigin/Fire.emitting = not $FireOrigin/Fire.emitting
		firelight.visible = not firelight.visible
#		$MeshInstance.cast_shadow = not $MeshInstance.cast_shadow
	else:
		$AnimationPlayer.stop()
		$FireOrigin/Fire.emitting = false
		firelight.visible = false
#		$MeshInstance.cast_shadow = true

func _on_Durability_timeout():
	$FireOrigin/Fire.emitting = false
	firelight.visible = false
	$AnimationPlayer.stop()
#	$MeshInstance.cast_shadow = true
