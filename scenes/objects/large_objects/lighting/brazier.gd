extends LargeObject

# eventually this is a tool/container-style item or large object that can be reloaded with candles which are disposable...not that you'd ever care to do that


@onready var floor_candelabra_drop_sound : AudioStream = load("res://resources/sounds/impacts/metal_and_gun/414848__link-boy__metal-bang.wav")


func _enter_tree():
	self.item_max_noise_level = 5
	self.item_drop_sound = floor_candelabra_drop_sound
