extends ToolItem
class_name LanternItem

export (bool) var can_attach = true
var has_ever_been_on = false 
var is_lit = true # true for testing to provide some light

onready var firelight = $Light
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
			firelight.visible = true
			is_lit = true
			$MeshInstance.cast_shadow = false
	else:
		is_lit = false

func _use_primary():
	if !durable_timer.is_stopped():
		$AnimationPlayer.play("flicker")
		firelight.visible = not firelight.visible
		$MeshInstance.cast_shadow = not $MeshInstance.cast_shadow
	else:
		$AnimationPlayer.stop()
		firelight.visible = false
		$MeshInstance.cast_shadow = true

func _on_Durability_timeout():
	$AnimationPlayer.stop()
	firelight.visible = false
	$MeshInstance.cast_shadow = true


func _item_state_changed(previous_state, current_state):
	if current_state == GlobalConsts.ItemState.INVENTORY:
		switch_away()


func switch_away():
	if not can_attach:
		$AnimationPlayer.stop()
		firelight.visible = false
		$MeshInstance.cast_shadow = false
		is_lit = false
	else:
		attach_to_belt()


func attach_to_belt():
	get_parent().owner.attach_to_belt(self)

