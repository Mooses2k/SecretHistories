extends Spatial


#onready var health_label = $Viewport/HBoxContainer/Health
#onready var input_label = $Viewport/HBoxContainer/InputPrompt
#onready var character = owner
export var raycast : NodePath
onready var pointcast = get_node(raycast)
var is_hp_triggered : bool = false
var is_hp_visible : bool = false
var is_moving : bool = false
var player_health : float = 100.0


func _ready():
	pass
	#var texture = $Viewport.get_texture()
	#texture.flags = Texture.FLAG_FILTER
	#(self.material_override as ShaderMaterial).set_shader_param("albedo", texture)


func _physics_process(delta):
	#health_label.text = str(character.current_health)
	#input_label.visible = owner.pickup_area.get_item_list().size() > 0
	if not player_health < 40:
		if pointcast.is_colliding():
			if pointcast.get_collider().name == "ground" and owner.colliding_pickable_items.empty():
				if not is_moving:
					if not is_hp_triggered:
						$Timer.stop()
						is_hp_triggered = true
						$AnimationPlayer.play("rotate")
						$Timer.start(2.0)
				else:
					if is_hp_triggered:
						_hide_hp()
			else:
				if is_hp_triggered:
					_hide_hp()
		else:
			if is_hp_triggered:
				_hide_hp()


func _hide_hp():
	$Timer.stop()
	is_hp_triggered = false
	
	if is_hp_visible:
		is_hp_visible = false
		$AnimationPlayer2.stop()
		$AnimationPlayer2.play("fadeOut")
		$AnimationPlayer.stop()


func _on_Player_is_hit(current_health):
	player_health = current_health
	
	if player_health < 75 and player_health > 39:
		if $MeshInstance2.is_visible_in_tree():
			$MeshInstance2.hide()
	
	if player_health < 40:
		if $MeshInstance.is_visible_in_tree():
			$MeshInstance.hide()


func _on_Timer_timeout():
	if is_hp_triggered:
		is_hp_visible = true
		$AnimationPlayer2.play("fadeIn")


func _on_Player_is_moving(is_player_moving):
	is_moving = is_player_moving
	if is_moving and is_hp_triggered:
		_hide_hp()
