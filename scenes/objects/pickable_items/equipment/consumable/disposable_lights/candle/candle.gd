extends ToolItem


var has_ever_been_on = false 
var is_lit = true

onready var firelight = $FireOrigin/Fire/Light
onready var durable_timer = $Durability

var material
var new_material

func _ready():
	material = $MeshInstance.get_surface_material(0)
	new_material = material.duplicate()
	$MeshInstance.set_surface_material(0,new_material)
	durable_timer.start()


func _process(delta):
	if is_lit == true:
		durable_timer.pause_mode = false
	else:
		durable_timer.pause_mode = true
	if self.mode == equipped_mode and has_ever_been_on == false:
			durable_timer.start()
			has_ever_been_on = true
#			firelight.visible = not firelight.visible
			$AnimationPlayer.play("flicker")
#			$FireOrigin/Fire.emitting = not $FireOrigin/Fire.emitting
#			$MeshInstance.get_surface_material(0).emission_enabled = not  $MeshInstance.get_surface_material(0).emission_enabled
#			$MeshInstance.cast_shadow = not $MeshInstance.cast_shadow
			is_lit = true
	else:
		is_lit = false


func _use_primary():
	if !durable_timer.is_stopped():
		$FireOrigin/Fire.emitting = not $FireOrigin/Fire.emitting
		firelight.visible = not firelight.visible
#		$MeshInstance.cast_shadow = not $MeshInstance.cast_shadow
		$MeshInstance.get_surface_material(0).emission_enabled  = not $MeshInstance.get_surface_material(0).emission_enabled 
	else:
		$AnimationPlayer.stop()
		$MeshInstance.get_surface_material(0).emission_enabled = false
		$FireOrigin/Fire.emitting = false
		firelight.visible = false
		$MeshInstance.cast_shadow = true
		

func _on_Durability_timeout():
	$FireOrigin/Fire.emitting = false
	firelight.visible = false
	$AnimationPlayer.stop()
	$MeshInstance.get_surface_material(0).emission_enabled = false
#	$MeshInstance.cast_shadow = true


func _item_state_changed(previous_state, current_state):
	if current_state == GlobalConsts.ItemState.INVENTORY:
		switch_away()


func switch_away():
	$FireOrigin/Fire.emitting = false
	firelight.visible = false
	$AnimationPlayer.stop()
	$MeshInstance.get_surface_material(0).emission_enabled = false
	is_lit = false
