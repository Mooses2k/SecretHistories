class_name VisibilityMask
extends MeshInstance

### Legacy visibility determiner ala the roguelike 'what you can see from your position', top-eown
### Not working since code changes in 2022


export var wall_height : float = 16.0
export var resolution : int = 2048
export var margin : float = 1.0

var cell_size = 2
var grid_size = 12
var target_node : Spatial

onready var mesh_instance = $Viewport/MeshInstance
onready var visibility_agent = $Viewport/VisibilityAgent
onready var viewport = $Viewport
onready var camera = $Viewport/Camera

var world : GameWorld


func _ready():
	var _error = GameManager.game.connect("player_spawned", self, "on_player_spawn")

	if self.get_parent() is GameWorld:
		world = self.get_parent() as GameWorld
		_error = world.connect("world_data_changed", self, "world_changed")
	else:
		printerr("Visibility mask should be a child of a GameWorld node")
		queue_free()

	var texture = viewport.get_texture()
	texture.flags = Texture.FLAG_FILTER
	(self.material_override as ShaderMaterial).set_shader_param("data_texture", texture)


func on_player_spawn(player : Spatial):
	self.target_node = player


func generate_mesh(grid_data : Array):
	var x = Vector3(1, 0, 0)
	var y = Vector3(0, 1, 0)
	var z = Vector3(0, 0, 1)
	var xx = Vector3(1, 0, 0)*cell_size
	var yy = Vector3(0, 1, 0)*wall_height
	var zz = Vector3(0, 0, 1)*cell_size
	mesh_instance.mesh = ArrayMesh.new()
	var vertices = Array()
	var normals = Array()
	var indices = Array()
	var last_index : int = 0
	for i in grid_data.size():
		for j in grid_data[i].size():
			if grid_data[i][j] == true:
				var oo = Vector3(i, 0, j)*cell_size
				vertices.push_back(oo)
				vertices.push_back(oo + xx)
				vertices.push_back(oo + xx + zz)
				vertices.push_back(oo + zz)

				normals.push_back(y)
				normals.push_back(y)
				normals.push_back(y)
				normals.push_back(y)

				indices.push_back(last_index + 0)
				indices.push_back(last_index + 1)
				indices.push_back(last_index + 2)
				indices.push_back(last_index + 0)
				indices.push_back(last_index + 2)
				indices.push_back(last_index + 3)

				last_index += 4

				if i - 1 < 0 or grid_data[i-1][j] == false:
					vertices.push_back(oo)
					vertices.push_back(oo + zz)
					vertices.push_back(oo + zz + yy)
					vertices.push_back(oo + yy)

					normals.push_back(x)
					normals.push_back(x)
					normals.push_back(x)
					normals.push_back(x)

					indices.push_back(last_index + 0)
					indices.push_back(last_index + 1)
					indices.push_back(last_index + 2)
					indices.push_back(last_index + 0)
					indices.push_back(last_index + 2)
					indices.push_back(last_index + 3)

					last_index += 4

				if i + 1 > grid_size - 1 or grid_data[i+1][j] == false:
					vertices.push_back(oo + xx)
					vertices.push_back(oo + xx + yy)
					vertices.push_back(oo + xx + yy + zz)
					vertices.push_back(oo + xx + zz)

					normals.push_back(-x)
					normals.push_back(-x)
					normals.push_back(-x)
					normals.push_back(-x)

					indices.push_back(last_index + 0)
					indices.push_back(last_index + 1)
					indices.push_back(last_index + 2)
					indices.push_back(last_index + 0)
					indices.push_back(last_index + 2)
					indices.push_back(last_index + 3)

					last_index += 4

				if j - 1 < 0 or grid_data[i][j-1] == false:
					vertices.push_back(oo)
					vertices.push_back(oo + yy)
					vertices.push_back(oo + yy + xx)
					vertices.push_back(oo + xx)

					normals.push_back(z)
					normals.push_back(z)
					normals.push_back(z)
					normals.push_back(z)

					indices.push_back(last_index + 0)
					indices.push_back(last_index + 1)
					indices.push_back(last_index + 2)
					indices.push_back(last_index + 0)
					indices.push_back(last_index + 2)
					indices.push_back(last_index + 3)

					last_index += 4

				if j + 1 > grid_size - 1 or grid_data[i][j+1] == false:
					vertices.push_back(oo + zz)
					vertices.push_back(oo + zz + xx)
					vertices.push_back(oo + zz + xx + yy)
					vertices.push_back(oo + zz + yy)

					normals.push_back(-z)
					normals.push_back(-z)
					normals.push_back(-z)
					normals.push_back(-z)

					indices.push_back(last_index + 0)
					indices.push_back(last_index + 1)
					indices.push_back(last_index + 2)
					indices.push_back(last_index + 0)
					indices.push_back(last_index + 2)
					indices.push_back(last_index + 3)

					last_index += 4
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PoolVector3Array(vertices)
	arrays[Mesh.ARRAY_NORMAL] = PoolVector3Array(normals)
	arrays[Mesh.ARRAY_INDEX] = PoolIntArray(indices)
	(mesh_instance.mesh as ArrayMesh).add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _process(_delta):
	if self.target_node and is_instance_valid(self.target_node):
		self.visibility_agent.global_transform = self.target_node.global_transform

	var active_camera : Camera = get_viewport().get_camera()
	self.camera.global_transform.origin.x = active_camera.global_transform.origin.x + active_camera.h_offset
	self.camera.global_transform.origin.z = active_camera.global_transform.origin.z - active_camera.v_offset

#	var floor_plane = Plane.PLANE_XZ
	var top_left = active_camera.project_position(Vector2.ZERO, active_camera.global_transform.origin.y)
	var bottom_right = active_camera.project_position(get_viewport().size, active_camera.global_transform.origin.y)
	var width = max(abs(top_left.x - bottom_right.x), abs(top_left.y - bottom_right.y)) + self.margin
	self.camera.size = width

	viewport.size = Vector2.ONE*resolution

	(self.material_override as ShaderMaterial).set_shader_param("offset", self.camera.global_transform.origin)
	(self.material_override as ShaderMaterial).set_shader_param("view_width", width)


func world_changed(world_data : Array, world_size : int):
	print_debug("Generating visibility mask world")
	print_debug("World size is : ", world_size)
	self.grid_size = world_size
	self.cell_size = world.CELL_SIZE
	self.generate_mesh(world_data)
	pass # Replace with function body.
