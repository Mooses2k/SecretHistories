extends Node3D
class_name DebugMarker

## Simple debug marker to visualize spawn positions
## Shows a colored cube with text label

### Member Variables and Dependencies -------------------------------------------------------------

#--- public variables - order: export > normal var > onready --------------------------------------
@export var marker_color: Color = Color.RED
@export var marker_size: float = 0.2
@export var label_text: String = "DEBUG"

#--- private variables - order: export > normal var > onready -------------------------------------
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var label: Label3D = $Label3D

### Built-in Virtual Overrides --------------------------------------------------------------------

func _ready():
	_setup_marker()
	_setup_label()
	
	# Auto-remove after 30 seconds to prevent clutter
	var timer := Timer.new()
	timer.wait_time = 30.0
	timer.one_shot = true
	timer.timeout.connect(_on_cleanup_timer)
	add_child(timer)
	timer.start()

### Public Methods --------------------------------------------------------------------------------

func set_marker_info(info_text: String, color: Color = Color.RED):
	label_text = info_text
	marker_color = color
	if is_inside_tree():
		_setup_marker()
		_setup_label()

### Private Methods -------------------------------------------------------------------------------

func _setup_marker():
	if not mesh_instance:
		return
	
	# Create a simple box mesh
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(marker_size, marker_size, marker_size)
	mesh_instance.mesh = box_mesh
	
	# Create material with the specified color
	var material := StandardMaterial3D.new()
	material.albedo_color = marker_color
	material.emission = marker_color * 0.3  # Slight glow
	material.flags_unshaded = true
	mesh_instance.material_override = material

func _setup_label():
	if not label:
		return
	
	label.text = label_text
	label.position = Vector3(0, marker_size + 0.1, 0)  # Position above marker
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func _on_cleanup_timer():
	print("DEBUG DebugMarker: Auto-removing debug marker: %s" % label_text)
	queue_free()

### -----------------------------------------------------------------------------------------------