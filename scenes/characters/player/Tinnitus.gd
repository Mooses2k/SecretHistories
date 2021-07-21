extends AudioStreamPlayer

# var occuring = false

func _process(delta):
	volume_db -= 0.1
	volume_db = clamp(volume_db, -31, 0)
	var should_play = volume_db > -30
	if playing != should_play:
		playing = should_play


#if not in body
#	tinnitus = false
