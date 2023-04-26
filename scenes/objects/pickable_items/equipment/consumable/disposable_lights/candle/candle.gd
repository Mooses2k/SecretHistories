extends ToolItem


#var has_ever_been_on = false
var is_lit = true

var material
var new_material

onready var firelight = $FireOrigin/Fire/Light


func _ready():
	light_timer = $Timer
	light_timer.connect("timeout", self, "light_depleted")
	burn_time = 3600.0
	light_timer.set_wait_time(burn_time)
	light_timer.start()
	
	material = $MeshInstance.get_surface_material(0)
	new_material = material.duplicate()
	$MeshInstance.set_surface_material(0,new_material)


#func _process(delta):
#	if is_lit == true:
#		light_timer.pause_mode = false
#	else:
#		light_timer.pause_mode = true

#	if self.mode == equipped_mode and has_ever_been_on == false:
#			burn_time.start()
#			has_ever_been_on = true
##			firelight.visible = not firelight.visible
#			$AnimationPlayer.play("flicker")
##			$FireOrigin/Fire.emitting = not $FireOrigin/Fire.emitting
##			$MeshInstance.get_surface_material(0).emission_enabled = not  $MeshInstance.get_surface_material(0).emission_enabled
##			$MeshInstance.cast_shadow = not $MeshInstance.cast_shadow
#			is_lit = true
#	else:
#		is_lit = false


func light():
	if not is_depleted:
		$AnimationPlayer.play("flicker")
		$LightSound.play()
	#	$FireOrigin/Fire.emitting = not $FireOrigin/Fire.emitting
		$FireOrigin/Fire.visible = not $FireOrigin/Fire.visible
		firelight.visible = not firelight.visible
		$MeshInstance.cast_shadow = false
		$MeshInstance.get_surface_material(0).emission_enabled  = not $MeshInstance.get_surface_material(0).emission_enabled
		
		is_lit = true
		light_timer.set_wait_time(burn_time)
		light_timer.start()


func unlight():
	if not is_depleted:
		$AnimationPlayer.stop()
		$BlowOutSound.play()
		$MeshInstance.get_surface_material(0).emission_enabled = false
	#	$FireOrigin/Fire.emitting = false
		$FireOrigin/Fire.visible = false
		firelight.visible = false
		$MeshInstance.cast_shadow = true
		
		is_lit = false
		stop_light_timer()


func _use_primary():
	if is_lit == false:
		light()
	else:
		unlight()


func _item_state_changed(previous_state, current_state):
	if current_state == GlobalConsts.ItemState.INVENTORY:
		switch_away()


func switch_away():
#	$FireOrigin/Fire.emitting = false
	$FireOrigin/Fire.visible = false
	firelight.visible = false
	$AnimationPlayer.stop()
	$MeshInstance.get_surface_material(0).emission_enabled = false
	is_lit = false
