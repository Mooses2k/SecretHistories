class_name TinyItem
extends PickableItem


@export var item_data : Resource
@export var amount : int = 1


func _ready():
	if $MeshInstance3D:
		if get_parent().owner:
			if get_parent().owner is GunItem:
				print("The Parent is: ", get_parent().owner)
				if get_parent().owner.owner_character.is_in_group("PLAYER"):
					$MeshInstance3D.layers = 1 | 2


## Plays pickup sound using a temporary audio player
## This ensures sound continues even after the item is destroyed
func play_pickup_sound():
	if not item_drop_sound:
		return
	
	# Create a temporary audio player (will self-destruct after playing)
	var pickup_audio_player = AudioStreamPlayer3D.new()
	pickup_audio_player.stream = item_drop_sound
	pickup_audio_player.bus = "Effects"
	pickup_audio_player.volume_db = item_sound_level if item_sound_level else 0
	pickup_audio_player.global_position = global_position
	
	# Add to scene root, NOT as child of this item (which is about to be destroyed)
	if get_tree() and get_tree().root:
		get_tree().root.add_child(pickup_audio_player)
	
	# Auto-cleanup when finished
	pickup_audio_player.finished.connect(func():
		if is_instance_valid(pickup_audio_player):
			pickup_audio_player.queue_free()
	)
	
	# Play the sound
	pickup_audio_player.play()
	
	# Set noise level for NPC detection
	if noise_level < 3:
		noise_level = 2
