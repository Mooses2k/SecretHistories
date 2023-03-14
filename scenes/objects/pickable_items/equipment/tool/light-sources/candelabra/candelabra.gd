extends ToolItem
class_name CandelabraItem


# eventually this is a tool/container-style item or large object that can be reloaded with candles which are disposable...not that you'd ever care to do that

# function this out better, lots of duplicated lines

var material
var new_material

onready var firelight = $Candle1/FireOrigin/Fire/Light

#var has_ever_been_on = false
var is_lit = true


func _ready():
	self.light_timer.connect("timeout", self, "light_depleted")
	self.burn_time = 1000.0
	self.light_timer.set_wait_time(self.burn_time)
	self.light_timer.start()
	
	material = $Candle1/MeshInstance.get_surface_material(0)
	new_material = material.duplicate()
	$Candle1/MeshInstance.set_surface_material(0,new_material)
	if $Candle2 != null:
		$Candle2/MeshInstance.set_surface_material(0,new_material)
	if $Candle3 != null:
		$Candle3/MeshInstance.set_surface_material(0,new_material)


#func _process(delta):
##	if is_lit == true:
##		light_timer.pause_mode = false
##	else:
##		light_timer.pause_mode = true
#
#	print(light_timer.time_left)
#	if self.mode == equipped_mode and has_ever_been_on == false:
#			burn_time.start()
#			has_ever_been_on = true
##			firelight.visible = not firelight.visible
#			$AnimationPlayer.play("flicker")
##			$Candle1/FireOrigin/Fire.visible = true
###			$Candle1/MeshInstance.emission_enabled = true
##			if $Candle2 != null:
##				$Candle2/FireOrigin/Fire.visible = true
##			if $Candle3 != null:
##				$Candle3/FireOrigin/Fire.visible = true
##			firelight.visible = true
##			$MeshInstance.cast_shadow = false
#			is_lit = true
#	else:
#		is_lit = false


func light():
	if not self.is_depleted:
		$AnimationPlayer.play("flicker")
		$LightSound.play()
		$Candle1/FireOrigin/Fire.visible = not $Candle1/FireOrigin/Fire.visible
		$Candle1/MeshInstance.cast_shadow = false
		$Candle1/MeshInstance.get_surface_material(0).emission_enabled  = not $Candle1/MeshInstance.get_surface_material(0).emission_enabled
		if $Candle2 != null:
			$Candle2/FireOrigin/Fire.visible = not $Candle2/FireOrigin/Fire.visible
			$Candle2/MeshInstance.cast_shadow = false
			$Candle2/MeshInstance.get_surface_material(0).emission_enabled  = not $Candle2/MeshInstance.get_surface_material(0).emission_enabled
		if $Candle3 != null:
			$Candle3/FireOrigin/Fire.visible = not $Candle3/FireOrigin/Fire.visible
			$Candle3/MeshInstance.cast_shadow = false
			$Candle3/MeshInstance.get_surface_material(0).emission_enabled  = not $Candle3/MeshInstance.get_surface_material(0).emission_enabled
		firelight.visible = true
		$MeshInstance.cast_shadow = false
		
		is_lit = true
		self.light_timer.set_wait_time(self.burn_time)
		self.light_timer.start()


func unlight():
	if not self.is_depleted:
		$AnimationPlayer.stop()
		$BlowOutSound.play()
		$Candle1/MeshInstance.get_surface_material(0).emission_enabled = false
		$Candle1/FireOrigin/Fire.visible = false
		$Candle1/MeshInstance.cast_shadow = true
		if $Candle2 != null:
			$Candle2/FireOrigin/Fire.visible = false
			$Candle2/MeshInstance.get_surface_material(0).emission_enabled = false
			$Candle2/MeshInstance.cast_shadow = true
		if $Candle3 != null:
			$Candle3/FireOrigin/Fire.visible = false
			$Candle3/MeshInstance.get_surface_material(0).emission_enabled = false
			$Candle3/MeshInstance.cast_shadow = true
		firelight.visible = false
		$MeshInstance.cast_shadow = true
		
		is_lit = false
		self.turnoff_light()


func _use_primary():
	if is_lit == false:
		light()
	else:
		unlight()


func _item_state_changed(previous_state, current_state):
	if current_state == GlobalConsts.ItemState.INVENTORY:
		switch_away()


func switch_away():
	pass
