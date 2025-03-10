extends Node

#TODO: do this through a signal instead
@onready var interact_controller: Node = $"../InteractController"
@onready var player_controller: Node = get_parent()

@export var inventory : Inventory

@export_range(0, 1, 1, "hide_slider","or_greater", "suffix:s")
var swap_hands_delay : float = 0.5

var is_reloading = false
var _swap_hands_timer : float = 0
var _holding_swap_hands = false

var _pressed_slot_key_count = 0
var _pressed_slot = -1

func is_inventory_locked() -> bool:
	return is_reloading


func cancel_throw():
	pass

func _process(delta: float) -> void:
	# If holding for too long, automatically swap hands
	if _holding_swap_hands:
		if _swap_hands_timer >= swap_hands_delay:
			inventory.swap_hands()
			print("swap hands")
			_holding_swap_hands = false
		else:
			_swap_hands_timer += delta
	_handle_inventory_and_grab_input(delta)

func _unhandled_input(event: InputEvent) -> void:
	if not is_inventory_locked():
		# offhand_cycling and hand swapping
		if event.is_action_pressed(&"playerhand|cycle_offhand_slot"):
			_holding_swap_hands = true
			_swap_hands_timer = 0.0
		elif event.is_action_released(&"playerhand|cycle_offhand_slot"):
			# If didn't swap hands yet, cycle slots instead
			if _holding_swap_hands:
				_cycle_offhand_slot()
				_holding_swap_hands = false

		# holster weapons
		if event.is_action_pressed(&"itm|holster_weapons"):
			var main_item : EquipmentItem = inventory.current_mainhand_equipment
			var off_item : EquipmentItem = inventory.current_offhand_equipment
			var unequiped := false
			if _is_weapon(main_item):
				inventory.unequip_mainhand_item()
				unequiped = true
			if _is_weapon(off_item):
				inventory.unequip_offhand_item()
				unequiped = true
			# If couldn't unequip anything, try to re-equip weapons
			if not unequiped:
				if not is_instance_valid(main_item):
					if _is_weapon(inventory.hotbar[inventory.current_mainhand_slot]):
						inventory.equip_mainhand_item()
				if not is_instance_valid(off_item):
					if _is_weapon(inventory.hotbar[inventory.current_offhand_slot]):
						inventory.equip_offhand_item()

	pass
func _is_weapon(item : EquipmentItem):
	return (item is MeleeItem or item is GunItem or item is BombItem)

func _cycle_offhand_slot():
	var start_slot = inventory.current_offhand_slot
	var new_slot = (start_slot + 1) % inventory.hotbar.size()
	while (new_slot != start_slot and (
				(
					inventory.hotbar[new_slot] != null
					and inventory.hotbar[new_slot].item_size != GlobalConsts.ItemSize.SIZE_SMALL
				)
				or new_slot == inventory.current_mainhand_slot
			)
		):
			new_slot = (new_slot + 1) % inventory.hotbar.size()
	if start_slot != new_slot:
		inventory.current_offhand_slot = new_slot
		print("Offhand slot cycled to ", new_slot)
		cancel_throw()
	pass



func _handle_inventory_and_grab_input(delta : float):
	_handle_hotbar_buttons()

#BUG: swapping items by holding the keys does not change the active slot index
func _handle_hotbar_buttons():
	#printt(slot_pressed, _pressed_hotbar_key_count)
	for i in range(inventory.HOTBAR_SIZE - 1):
		if Input.is_action_just_pressed("hotbar_%d" % [i + 1]) and not is_inventory_locked():
			# track number of buttons pressed to make sure we don't switch items after swapping, while still holding first button
			_pressed_slot_key_count += 1
			# is another hotbar button currently held?
			if _pressed_slot_key_count == 2:
				inventory.swap_slots(_pressed_slot, i)
				#return

	for i in range(inventory.HOTBAR_SIZE - 1):
		if Input.is_action_just_released("hotbar_%d" % [i + 1]) and not is_inventory_locked():
			# did we swap slots?
			_pressed_slot_key_count -= 1
			# implies no other hotbar button pressed in the meantime
			if _pressed_slot_key_count == 0:
				# slot that was pressed -> normal logic
				# Don't select current offhand slot and don't select 10 because it's hotbar_11, used for holstering offhand item, below
				if i != inventory.current_offhand_slot and i != 10:
					inventory.drop_bulky_item()
					inventory.current_mainhand_slot = i
					cancel_throw()
				# clear which slot was pressed (could do double-duty as are we swapping?)
				_pressed_slot = -1 # invalid slot

	for i in range(inventory.HOTBAR_SIZE - 1):
		if Input.is_action_pressed("hotbar_%d" % [i + 1]) and not is_inventory_locked():
			# if didn't just swap:
			if _pressed_slot == -1:
				# record which slot was pressed
				_pressed_slot = i
