class_name LanternItem
extends ToolItem

# TODO: rework lighting code generally, function this out better, lots of duplicated lines here and in candelabra.gd, torch.gd, candle.gd


signal item_is_dropped

var burn_time : float
var is_depleted : bool = false
var is_dropped: bool = false
var is_just_dropped: bool = true
var light_timer
var random_number
export var is_oil_based : bool = false
export(float, 0.0, 1.0) var life_percentage_lose : float = 0.0
export(float, 0.0, 1.0) var prob_going_out : float = 0.0

var is_lit = true # starts on
onready var firelight = $Light


func _ready():
	if not is_connected("body_entered", self, "play_drop_sound"):
		connect("body_entered", self, "play_drop_sound")
	light_timer = $Timer
	
	light_timer.connect("timeout", self, "light_depleted")
	if is_oil_based:
		burn_time = 1800.0
	else:
		burn_time = 3600.0
	light_timer.set_wait_time(burn_time)
	light_timer.start()


func _process(delta):
	if item_state == GlobalConsts.ItemState.DROPPED:
		$Ignite/CollisionShape.disabled = false
		is_dropped = true
		
		if is_dropped and not is_just_dropped:
			is_just_dropped = true
			self.emit_signal("item_is_dropped")
			item_drop()
	else:
		$Ignite/CollisionShape.disabled = true
		is_dropped = false
		is_just_dropped = false


func _use_primary():
	if is_lit == false:
		light()
	else:
		unlight()


func light():
	if not is_depleted:
		$AnimationPlayer.play("flicker")
		$LightSound.play()
		firelight.visible = true
		$MeshInstance.cast_shadow = false
		
		is_lit = true
		light_timer.set_wait_time(burn_time)
		light_timer.start()


func unlight():
	if not is_depleted:
		$AnimationPlayer.stop()
		firelight.visible = false
		$MeshInstance.cast_shadow = true
		
		is_lit = false
		stop_light_timer()


func _item_state_changed(previous_state, current_state):
	if current_state == GlobalConsts.ItemState.INVENTORY:
		if is_lit:
			var sound = $BlowOutSound.duplicate()
			GameManager.game.level.add_child(sound)
			sound.global_transform = $BlowOutSound.global_transform
			sound.connect("finished", sound, "queue_free")
			sound.play()
		owner_character.inventory.switch_away_from_light(self)


func attach_to_belt():
	owner_character.inventory.attach_to_belt(self)
	is_in_belt = true


func light_depleted():
	burn_time = 0
	unlight()
	is_depleted = true


func stop_light_timer():
	burn_time = light_timer.get_time_left()
	print("current burn time " + str(burn_time))
	light_timer.stop()


func item_drop():
	stop_light_timer()
	burn_time -= (burn_time * life_percentage_lose)
	print("reduced burn time " + str(burn_time))
	random_number = rand_range(0.0, 1.0)
	
	light_timer.set_wait_time(burn_time)
	light_timer.start()
	
	print("Linear velocity of candle: ", linear_velocity.length())
	if linear_velocity.length() > 0.1:
		if random_number < prob_going_out:
			unlight()
