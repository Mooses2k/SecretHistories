extends ToolItem


#var has_ever_been_on = false 
var is_lit = true

onready var firelight = $FireOrigin/Fire/Light
onready var burn_time = $Durability


#func _ready():
#	burn_time.start()


func _process(delta):
	if is_lit == true:
		burn_time.pause_mode = false
	else:
		burn_time.pause_mode = true
	
#	if self.mode == equipped_mode and has_ever_been_on == false:
#			burn_time.start()
#			has_ever_been_on = true
#			$AnimationPlayer.play("flicker")
#			$FireOrigin/Fire.emitting = true
#			$FireOrigin/EmberDrip.emitting = true
#			$FireOrigin/Smoke.emitting = true
#			firelight.visible = not firelight.visible
#			$MeshInstance.cast_shadow = false
#			is_lit = true
#	else:
#		is_lit = false


func light():
	$AnimationPlayer.play("flicker")
	$LightSound.play()
	$FireOrigin/Fire.emitting = true
	$FireOrigin/EmberDrip.emitting = true
	$FireOrigin/Smoke.emitting = true
	firelight.visible = true
	$MeshInstance.cast_shadow = false
	is_lit = true


func unlight():
	$AnimationPlayer.stop()
	$BlowOutSound.play()
	$FireOrigin/Fire.emitting = false
	$FireOrigin/EmberDrip.emitting = false
	$FireOrigin/Smoke.emitting = false
	firelight.visible = false
	$MeshInstance.cast_shadow = true
	is_lit = false


func _item_state_changed(previous_state, current_state):
	if current_state == GlobalConsts.ItemState.INVENTORY:
		switch_away()

func switch_away():
	$AnimationPlayer.stop()
	$FireOrigin/Fire.emitting = false
	$FireOrigin/EmberDrip.emitting = false
	$FireOrigin/Smoke.emitting = false
	firelight.visible = false
	$MeshInstance.cast_shadow = true
	is_lit = false


func _use_primary():
	if is_lit == false:
		light()
	else:
		unlight()


func _on_Durability_timeout():
	unlight()
