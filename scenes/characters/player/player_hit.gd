extends CanvasLayer


#for testing
func _input(event):
	if event is InputEvent and event.is_action_pressed("kick"):
		if not $ColorRect.is_visible_in_tree():
			$ColorRect.show()
		$AnimationPlayer.play("hit_effect")
	
	if event is InputEvent and event.is_action_pressed("reload"):
		$TextureRect.show()
	


func _on_Player_player_is_hit(current_health, max_health):
	if not $ColorRect.is_visible_in_tree():
		$ColorRect.show()
	if current_health < (max_health * 0.25):
		$TextureRect.show()
	$AnimationPlayer.play("hit_effect")
