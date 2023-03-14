extends ToolItem
class_name LanternItem


#var has_ever_been_on = true # starts on
var is_lit = true # starts on
onready var firelight = $Light


func _ready():
	self.light_timer.connect("timeout", self, "light_depleted")
	if self.is_oil_based:
		self.burn_time = 1800.0
	else:
		self.burn_time = 3600.0
	self.light_timer.set_wait_time(self.burn_time)
	self.light_timer.start()


#func _process(delta):
#	if is_lit == true:
#		light_timer.pause_mode = false
#	else:
#		light_timer.pause_mode = true

#	if self.mode == equipped_mode and has_ever_been_on == false:
##			burn_time.start()   # done in Inspector
#			has_ever_been_on = true
#			firelight.visible = true
#			$MeshInstance.cast_shadow = false
#			is_lit = true
#	else:
#		is_lit = false


func light():
	if not self.is_depleted:
		$AnimationPlayer.play("flicker")
		$LightSound.play()
		firelight.visible = true
		$MeshInstance.cast_shadow = false
		
		is_lit = true
		self.light_timer.set_wait_time(self.burn_time)
		self.light_timer.start()


func unlight():
	if not self.is_depleted:
		$AnimationPlayer.stop()
		$BlowOutSound.play()
		firelight.visible = false
		$MeshInstance.cast_shadow = true
		
		is_lit = false
		self.turnoff_light()


func _item_state_changed(previous_state, current_state):
	if current_state == GlobalConsts.ItemState.INVENTORY:
		switch_away()


func switch_away():
	if not can_attach:
#		unlight()
		pass
	else:
		attach_to_belt()


func attach_to_belt():
	is_in_belt = true
	get_parent().owner.inventory.attach_to_belt(self)


func _use_primary():
	if is_lit == false:
		light()
	else:
		unlight()
