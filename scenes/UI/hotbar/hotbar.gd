extends MarginContainer

var inventory : Node = null


func _ready():
	var game = GameManager.game
	var player = game.player
	if player == null:
		yield(game, "player_spawned")
		player = game.player
	inventory = player.inventory
	if inventory == null:
		yield(player, "ready")
		inventory = player.inventory
	initialize_hotbar()

func initialize_hotbar():
	inventory.connect("hotbar_changed", self, "hotbar_changed")
	inventory.connect("current_slot_changed", self, "current_slot_changed")

	for i in inventory.HOTBAR_SIZE: #0 to 9
		var item = inventory.hotbar[i] as EquipmentItem
		var item_name = item.item_name if item != null else ""
		var item_amount = 1 if item != null else 0
		var slot = $VBoxContainer.get_child(i)
		slot.set_name(item_name)
		slot.set_stack_size(str(item_amount))
		if i != inventory.current_slot:
			slot.modulate.a = 0.6
		else:
			slot.modulate.a = 1

func hotbar_changed(slot):
	#from that number, get_child (0 is hotbar 1)
	#set visible when changed, not always, on timer, with fade, later (modulation)
	#hotbar.text = new name
	var item = inventory.hotbar[slot] as EquipmentItem
	var item_name = item.item_name if item != null else ""
	var item_amount = 1 if item != null else 0
	var hotbar_slot = $VBoxContainer.get_child(slot)
	hotbar_slot.set_name(item_name)
	hotbar_slot.set_stack_size(str(item_amount))

func current_slot_changed(previous, current):
	#set all modulates to 0.6, then current to 1.0
	$VBoxContainer.get_child(previous).modulate.a = 0.6
	$VBoxContainer.get_child(current).modulate.a = 1
