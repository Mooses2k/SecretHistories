extends EquipmentItem;
class_name ToolItem


var burn_time : float
var is_depleted : bool = false
export var is_oil_based : bool = false
onready var light_timer = $Timer


#func _enter_tree():
#	self.light_timer = Timer.new()
#	self.light_timer.name = "LightDuration"
#	add_child(light_timer)
#	self.light_timer.set_autostart(false)
#	self.light_timer.connect("timeout", self, "unlight")


func _process(delta):
	if item_state == GlobalConsts.ItemState.DROPPED:
		$ignite/CollisionShape.disabled = false
	else:
		$ignite/CollisionShape.disabled = true


func light():
	pass


func unlight():
	pass


func light_depleted():
	self.burn_time = 0
	unlight()
	self.is_depleted = true


func turnoff_light():
	self.burn_time = self.light_timer.get_time_left()
	self.light_timer.stop()
