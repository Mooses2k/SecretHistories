extends CanvasLayer


var tween_speed = 0.7
var is_fade_in = false

onready var opacity_target = [0.1, 0.2]
onready var debug_label: RichTextLabel = $RichTextLabel
onready var keybind_defaults: RichTextLabel = $KeybindDefaults
onready var color_rect: TextureRect = $ColorRect
onready var texture_rect: TextureRect = $TextureRect
onready var animation_player: AnimationPlayer = $AnimationPlayer
onready var tween: Tween = $Tween


func _process(delta):
	pass
#	var player := owner as Player
#	debug_label.text = (
#		"Player current_health = " + str(player.current_health) + "\n"
#		+ "Player stamina = " + str(player.stamina) + "\n"
#		+ "Player light_level = " + str(player.light_level) + "\n"
#		+ "Player noise_level = " + str(player.noise_level) + "\n"
#		+ "Player on floor = " +  str(player.is_on_floor()) + "\n"
#		+ "Current strata = " +  str(GameManager.game.current_floor_level) + "\n"
#		+ "Player position = " +  str(player.translation) + "\n"
#		+ "Current FPS = " +  str(Performance.get_monitor(Performance.TIME_FPS)) + "\n"
#	)


func _input(event):
	if event is InputEvent and event.is_action_pressed("misc|help_info"):
		keybind_defaults.visible = !keybind_defaults.visible
		debug_label.visible = !debug_label.visible


func _on_Player_is_hit(current_health):
	if not color_rect.is_visible_in_tree():
		color_rect.show()
	
	if animation_player.is_playing():
		animation_player.stop()
	animation_player.play("hit_effect")
	
	if current_health <= 5:
		opacity_target[0] = 0.7
		opacity_target[1] = 0.98
	elif current_health <= 10:
		tween_speed = 0.4
		opacity_target[0] = 0.6
		opacity_target[1] = 0.8
	elif current_health <= 15:
		opacity_target[0] = 0.5
		opacity_target[1] = 0.7
	elif current_health <= 20:
		tween_speed = 0.5
		opacity_target[0] = 0.4
		opacity_target[1] = 0.6
	elif current_health <= 25:
		opacity_target[0] = 0.3
		opacity_target[1] = 0.5
	elif current_health <= 30:
		tween_speed = 0.6
		opacity_target[0] = 0.2
		opacity_target[1] = 0.4
	elif current_health <= 35:
		opacity_target[0] = 0.1
		opacity_target[1] = 0.3
	elif current_health <= 40:
		if not texture_rect.is_visible_in_tree():
			texture_rect.show()
		
		if not tween.is_active() and not tween.is_active():
			_start_fade_in()
		opacity_target[0] = 0.05
		opacity_target[1] = 0.2


func _start_fade_in():
	is_fade_in = true
	tween.interpolate_property(texture_rect, "modulate", 
			Color(1, 1, 1, opacity_target[0]), Color(1, 1, 1, opacity_target[1]), tween_speed, Tween.TRANS_SINE, Tween.EASE_OUT)    
	tween.start()


func _start_fade_out():
	is_fade_in = false
	tween.interpolate_property(texture_rect, "modulate", 
			Color(1, 1, 1, opacity_target[1]), Color(1, 1, 1, opacity_target[0]), tween_speed, Tween.TRANS_SINE, Tween.EASE_IN)    
	tween.start()


func _on_Tween_tween_completed(object, key):
	if is_fade_in:
		_start_fade_out()
	else:
		_start_fade_out()


func _on_Player_character_died():
	texture_rect.hide()
	color_rect.hide()
