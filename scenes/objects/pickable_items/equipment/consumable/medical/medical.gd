class_name MedicalItem
extends ConsumableItem

### For now, if bandage or something, remove it on use and add those HP up to max
### For doctor's bag or dentist's kit, use charges up to HP max, but keep item unless exhausted

### TODO: Eventually move the bag and box to containers


export var heal_amount : int = 10   # Should probably be 10 for consumables & 1 for containers
export var speed_boost : int = 0

export var time_to_use : int = 5
onready var use_timer = $UseTime

export var max_charges_held : int = 1
export var max_charges_usable_at_once = 1
var charges_held : int = 1
var charges_used : int = 0


func _ready():
	use_timer.set_wait_time(time_to_use)
	
	if max_charges_held > 1:   # If a medical container, give it some starting charges
		_set_starting_charges()


func _set_starting_charges():
	charges_held = randi() % (max_charges_held + 1)


func _use_primary():
	# TODO: animation
	# TODO: holding down to use, not just tap
	if owner_character.current_health < owner_character.max_health:
		if use_timer.is_stopped():
			use_timer.start()
			# Add something here to play the prep sound if it exists, wait til finished, then play use sound
			$Sounds/Use.play()


# TODO: Two ways to reload a medical container: 1) pickup a medical consumable, 2) reload when there's medical consumables in your inventory; this func is that one
#func _reload():
#	pass


# TODO: when pickup medical consumable, check how much space in container and put appropriate amount
#func check_space_to_fill():
#	pass


func _on_UseTime_timeout():
	var health_below_max = owner_character.max_health - owner_character.current_health
	print("Health below max: ", health_below_max)
	
	if max_charges_held == 1:
		charges_used = 1
	
	if max_charges_held > 1:   # This is a container for medical consumables
		if health_below_max > charges_held:
			charges_used = charges_held
		else:
			charges_used = health_below_max
		charges_held -= charges_used

	owner_character.heal(charges_used * heal_amount)
	print("Healed ", owner_character, " for ", (charges_used * heal_amount))
	
	# TODO: if speed_boost > 0:
	#	set a timer and give most player actions a bit of haste
	
	$Sounds/UseComplete.play()   # Currently doesn't play due to queue_free below
	
	# This is a single-use consumable, se we're done with it
	if max_charges_held == 1:
		owner_character.drop_consumable(self)
		queue_free()
		# TODO: this should drop an empty bottle or syringe, only queue_free if nothing's left, like bandage
