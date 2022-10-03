extends CanvasLayer


#for testing
var health = 100
func _input(event):
	if event is InputEvent and event.is_action_pressed("kick"):
		if not $ColorRect.is_visible_in_tree():
			$ColorRect.show()
		if $AnimationPlayer.is_playing():
			$AnimationPlayer.stop()
		$AnimationPlayer.play("hit_effect")
		health -= 5
		
		if health <= 5:
			$TextureRect.modulate.a = 1.0
		elif health <= 10:
			$TextureRect.modulate.a = 0.9
		elif health <= 15:
			$TextureRect.modulate.a = 0.7
		elif health <= 20:
			$TextureRect.modulate.a = 0.5
		elif health <= 25:
			$TextureRect.modulate.a = 0.3
		elif health <= 30:
			$TextureRect.modulate.a = 0.2
		elif health <= 35:
			$TextureRect.modulate.a = 0.1
		elif health <= 40:
			if not $TextureRect.is_visible_in_tree():
				$TextureRect.show()
			$TextureRect.modulate.a = 0.05


func _on_Player_player_is_hit(current_health):
	if not $ColorRect.is_visible_in_tree():
		$ColorRect.show()
	$AnimationPlayer.play("hit_effect")
	
	if current_health <= 40 and not $TextureRect.is_visible_in_tree():
		$TextureRect.show()
	
	if current_health <= 5:
		$TextureRect.modulate.a = 1.0
	elif current_health <= 10:
		$TextureRect.modulate.a = 0.9
	elif current_health <= 15:
		$TextureRect.modulate.a = 0.7
	elif current_health <= 20:
		$TextureRect.modulate.a = 0.5
	elif current_health <= 25:
		$TextureRect.modulate.a = 0.3
	elif current_health <= 30:
		$TextureRect.modulate.a = 0.2
	elif current_health <= 35:
		$TextureRect.modulate.a = 0.1
	elif current_health <= 40:
		$TextureRect.modulate.a = 0.05
		
