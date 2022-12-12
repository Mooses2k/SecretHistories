extends RigidBody

# eventually this is a tool/container-style item or large object that can be reloaded with candles which are disposable...not that you'd ever care to do that


#onready var firelight = $FireOrigin/Fire/Light
#onready var DurableTimer = $Durability
#
#var has_ever_been_on = false 
#var is_lit = false
#
#
#func _process(delta):
#	if is_lit == true:
#		DurableTimer.pause_mode = false
#	else:
#		DurableTimer.pause_mode = true
#	if has_ever_been_on == false:
#			DurableTimer.start()
#			has_ever_been_on = true
#			firelight.visible = not firelight.visible
#			$AnimationPlayer.play("flicker")
#			$FireOrigin/Fire.emitting = true
#			$FireOrigin/EmberDrip.emitting = true
#			$FireOrigin/Smoke.emitting = true
#			is_lit = true
#	else:
#		is_lit = false
#
#
#func _use_primary():
#	if !DurableTimer.is_stopped():
#		firelight.visible = not firelight.visible
#		$AnimationPlayer.play("flicker")
#		$FireOrigin/Fire.emitting = not $FireOrigin/Fire.emitting
#		$FireOrigin/EmberDrip.emitting = not $FireOrigin/EmberDrip.emitting
#		$FireOrigin/Smoke.emitting = not $FireOrigin/Smoke
#	else:
#		firelight.visible = false
#		$AnimationPlayer.stop()
#		$FireOrigin/Fire.emitting = false
#		$FireOrigin/EmberDrip.emitting = false
#		$FireOrigin/Smoke.emitting = false
#
#
#func _on_Durability_timeout():
#	firelight.visible = false
#	$AnimationPlayer.stop()
#	$FireOrigin/Fire.emitting = false
#	$FireOrigin/EmberDrip.emitting = false
#	$FireOrigin/Smoke.emitting = false
