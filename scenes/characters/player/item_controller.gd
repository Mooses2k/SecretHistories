extends Node


@export var inventory : Inventory

@export var use_held_threshold = 0.25
var use_hold_timer_mainhand = 0
var use_hold_timer_offhand = 0

@export var unload_threshold = 0.5
var reload_hold_timer = 0
var unloaded : bool = false

@onready var player_controller: Node = get_parent()


#TODO: disable held action if switching items (new item should not be held automatically)
func _process(delta: float) -> void:
	var main_item = inventory.get_mainhand_item()
	if Input.is_action_pressed(&"playerhand|mainhand_use"):
		use_hold_timer_mainhand += delta
		if use_hold_timer_mainhand > use_held_threshold:
			if main_item is EquipmentItem and main_item.has_held_use() and not main_item.is_held():
				main_item.set_held_use(true)
	if Input.is_action_pressed(&"playerhand|offhand_use"):
		use_hold_timer_offhand += delta
		if use_hold_timer_offhand > use_held_threshold:
			var off_item = inventory.get_offhand_item()
			if off_item is EquipmentItem and off_item.has_held_use() and not off_item.is_held():
				off_item.set_held_use(true)
	if Input.is_action_pressed(&"player|reload") and not unloaded:
		reload_hold_timer += delta
		if reload_hold_timer > unload_threshold:
			if main_item is GunItem:
				main_item.use_unload()
				unloaded = true


func _unhandled_input(event: InputEvent) -> void:
	var main_item = inventory.get_mainhand_item()
	if main_item is EquipmentItem:
		if event.is_action_pressed(&"playerhand|mainhand_use"):
			if not main_item.has_held_use():
				main_item.use_primary()
			else:
				use_hold_timer_mainhand = 0
		elif event.is_action_released(&"playerhand|mainhand_use"):
			if main_item.has_held_use():
				if not main_item.is_held():
					main_item.use_primary()
				else:
					main_item.set_held_use(false)
		
		elif event.is_action_pressed(&"player|reload"):
			unloaded = false
			reload_hold_timer = 0
		elif event.is_action_released(&"player|reload"):
			if not unloaded and main_item is GunItem or MedicalItem:
				main_item.use_reload()
					
	var off_item = inventory.get_offhand_item()
	if off_item is EquipmentItem:
		if event.is_action_pressed(&"playerhand|offhand_use"):
			if not off_item.has_held_use():
				off_item.use_primary()
			else:
				use_hold_timer_offhand = 0
		if event.is_action_released(&"playerhand|offhand_use"):
			if off_item.has_held_use():
				if not off_item.is_held():
					off_item.use_primary()
				else:
					off_item.set_held_use(false)
