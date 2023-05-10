extends Area


func _ready():
	self.connect("body_entered", self, "equipment_entered")


func equipment_entered(body):
	if body.name == "ShotgunItem" and owner.inventory.current_mainhand_slot == 0:
		owner.inventory.add_item(body)
		print("picked up weapon")
	
	if body is TinyItem and owner.inventory.current_mainhand_equipment:
		if owner.inventory.current_mainhand_equipment.ammo_types.has(body.item_data):
			owner.inventory.add_item(body)
			print("picked up ammo")
		
		for ammo_type in owner.inventory.current_mainhand_equipment.ammo_types:
			print("ammo type = " + str(ammo_type) + "== body.item_data = " + str(body.item_data))
			if ammo_type == body.item_data and owner.inventory.tiny_items.has(ammo_type):
				if owner.inventory.tiny_items[ammo_type] < 1:
					owner.inventory.add_item(body)
					print("picked up ammo")
