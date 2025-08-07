extends Node


#TODO: do this through a signal instead
@onready var interact_controller: Node = $"../InteractController"
@onready var player_controller: Node = get_parent()
@onready var character : HumanoidCharacter = owner as HumanoidCharacter

@export var inventory : Inventory

@export_range(0, 1, 1, "hide_slider","or_greater", "suffix:s")
var swap_hands_delay : float = 0.5

var _swap_hands_timer : float = 0
var _holding_swap_hands = false

var _pressed_slot_key_count : int = 0
var _pressed_slot : int = -1
var _slots_swapped : bool = false


func is_inventory_locked() -> bool:
	return character.state.is_reloading


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
		elif event.is_action_pressed(&"itm|holster_weapons"):
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
		
		# hotbar scrolling
		elif event.is_action_pressed(&"itm|next_hotbar_item"):
			inventory.drop_bulky_item()
			var next_slot = get_next_valid_mainhand_slot(inventory.current_mainhand_slot, 1)
			inventory.current_mainhand_slot = next_slot
			print(inventory.current_mainhand_slot)
		elif event.is_action_pressed(&"itm|previous_hotbar_item"):
			inventory.drop_bulky_item()
			var next_slot = get_next_valid_mainhand_slot(inventory.current_mainhand_slot, -1)
			inventory.current_mainhand_slot = next_slot
			print(inventory.current_mainhand_slot)
	pass

# Helper function to find the next valid main hand slot that skips the equipped offhand slot
func get_next_valid_mainhand_slot(current_slot: int, direction: int) -> int:
	var next_slot = current_slot
	var attempts = 0
	var max_attempts = 11  # Number of hotbar slots
	
	while attempts < max_attempts:
		next_slot = wrapi(next_slot + direction, 0, 11)
		
		# Skip if this slot is the current offhand slot
		if next_slot == inventory.current_offhand_slot:
			attempts += 1
			continue
			
		# Found a valid slot
		return next_slot
		
		attempts += 1
	
	# Fallback to original slot if no valid slot found (shouldn't happen)
	return current_slot


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


func _handle_hotbar_buttons():
	#printt(slot_pressed, _pressed_hotbar_key_count)
	for i in range(inventory.HOTBAR_SIZE - 1):
		if Input.is_action_just_pressed("hotbar_%d" % [i + 1]):
			if _pressed_slot_key_count == 0:
				_pressed_slot = i
			# track number of buttons pressed to make sure we don't switch items after swapping, while still holding first button
			_pressed_slot_key_count += 1
			# is another hotbar button currently held?
			if _pressed_slot_key_count == 2 and _pressed_slot >= 0:
				inventory.swap_slots(_pressed_slot, i)
				_slots_swapped = true
	
	for i in range(inventory.HOTBAR_SIZE - 1):
		if Input.is_action_just_released("hotbar_%d" % [i + 1]):
			if i == _pressed_slot:
				_pressed_slot = -1
			# did we swap slots?
			_pressed_slot_key_count -= 1
			# implies no other hotbar button pressed in the meantime
			if _pressed_slot_key_count == 0:
				if _slots_swapped:
					_slots_swapped = false
				elif not is_inventory_locked():
					# slot that was pressed -> normal logic
					# Don't select current offhand slot and don't select 10 because it's hotbar_11, used for holstering offhand item, below
					if i != inventory.current_offhand_slot and i != 10:
						inventory.drop_bulky_item()
						inventory.current_mainhand_slot = i
						cancel_throw()
