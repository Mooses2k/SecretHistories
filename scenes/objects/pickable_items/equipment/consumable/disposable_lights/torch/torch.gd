extends ToolItem


#var has_ever_been_on = false
var is_lit = true

onready var firelight = $FireOrigin/Fire/Light


func _ready():
	self.light_timer.connect("timeout", self, "light_depleted")
	self.burn_time = 600.0
	self.light_timer.set_wait_time(self.burn_time)
	self.light_timer.start()


#func _process(delta):
#	if is_lit == true:
#		light_timer.pause_mode = false
#	else:
#		light_timer.pause_mode = true
#	
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
	if not self.is_depleted:
		$AnimationPlayer.play("flicker")
		$Sounds/LightSound.play()
		$Sounds/Burning.play()
		$FireOrigin/Fire.emitting = true
		$FireOrigin/EmberDrip.emitting = true
		$FireOrigin/Smoke.emitting = true
		firelight.visible = true
		$MeshInstance.cast_shadow = false
		
		is_lit = true
		self.light_timer.set_wait_time(self.burn_time)
		self.light_timer.start()


func unlight():
	if not self.is_depleted:
		$AnimationPlayer.stop()
		$Sounds/BlowOutSound.play()
		$Sounds/Burning.stop()
		$FireOrigin/Fire.emitting = false
		$FireOrigin/EmberDrip.emitting = false
		$FireOrigin/Smoke.emitting = false
		firelight.visible = false
		$MeshInstance.cast_shadow = true
		
		is_lit = false
		self.turnoff_light()


func _item_state_changed(previous_state, current_state):
	if current_state == GlobalConsts.ItemState.INVENTORY:
		switch_away()


func switch_away():
	pass
#	unlight()


func _use_primary():
	if is_lit == false:
		light()
	else:
		unlight()
