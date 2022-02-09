extends MeshInstance


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
onready var health_label = $Viewport/HBoxContainer/Health
onready var input_label = $Viewport/HBoxContainer/InputPrompt
onready var character = owner
# Called when the node enters the scene tree for the first time.
func _ready():
	var texture = $Viewport.get_texture()
	texture.flags = Texture.FLAG_FILTER
	(self.material_override as ShaderMaterial).set_shader_param("albedo", texture)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	health_label.text = str(character.current_health)
	input_label.visible = owner.pickup_area.get_item_list().size() > 0


#	pass
