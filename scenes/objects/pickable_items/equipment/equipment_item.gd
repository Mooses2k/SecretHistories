class_name EquipmentItem
extends PickableItem


signal used_primary()
signal used_secondary()
signal used_reload()

export (bool) var can_attach = false
export(GlobalConsts.ItemSize) var item_size : int = GlobalConsts.ItemSize.SIZE_MEDIUM

export var item_name : String = "Equipment"
export var horizontal_holding : bool = false

var is_in_belt = false
var has_equipped = false
onready var hold_position = $"%HoldPosition"


func _ready():
	if horizontal_holding == true:
		hold_position.rotation_degrees.z = 90
	connect("body_entered", self, "play_drop_sound")


# Override this function for (Left-Click and E, typically) use actions
func _use_primary():
	print("use primary")
	pass


# Right-click, typically
func _use_secondary():
	print("use secondary")
	pass


# Reloads can only happen in main-hand
func _use_reload():
	print("use reload")
	pass


func use_primary():
	_use_primary()
	emit_signal("used_primary")


func use_secondary():
	_use_secondary()
	emit_signal("used_secondary")


func use_reload():
	_use_reload()
	emit_signal("used_reload")


func get_hold_transform() -> Transform:
	return $HoldPosition.transform.inverse()


## WORKAROUND for https://github.com/godotengine/godot/issues/62435
# Bug here where when player rotates, items does a little circle thing in hand
func _physics_process(delta):
	if self.item_state == GlobalConsts.ItemState.EQUIPPED:
		transform = get_hold_transform()
