extends MeshInstance


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
onready var label = $Viewport/CenterContainer/Label
onready var character : Character = owner as Character
# Called when the node enters the scene tree for the first time.
func _ready():
	var texture = $Viewport.get_texture()
	texture.flags = Texture.FLAG_FILTER
	(self.material_override as ShaderMaterial).set_shader_param("albedo", texture)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	label.text = str(character.current_health)
#	pass
