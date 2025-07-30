extends RefCounted

const DOWNSAMPLE := preload("res://scenes/screen_filters/downsample.glsl") as RDShaderFile
const LOCAL_GROUP_SIZE := Vector3i(8, 8, 1)

var shader : RID
var pipeline : RID
var rd : RenderingDevice

func _init(rendering_device : RenderingDevice) -> void:
	rd = rendering_device
	shader = rd.shader_create_from_spirv(DOWNSAMPLE.get_spirv())
	assert(shader.is_valid())
	pipeline = rd.compute_pipeline_create(shader)
	assert(pipeline.is_valid())

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if shader.is_valid():
			rd.free_rid(shader)

func downsample(input_image : RID, output_image : RID, scale : int) -> void:
	var out_format := rd.texture_get_format(output_image)
	var buffer_size := Vector2i(out_format.width, out_format.height)

	var groups : Vector3i = (
		Vector3i(
			buffer_size.x,
			buffer_size.y,
			1
		) - Vector3i.ONE
	) / LOCAL_GROUP_SIZE + Vector3i.ONE
	var in_img_uniform := RDUniform.new()
	in_img_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	in_img_uniform.binding = 0
	in_img_uniform.add_id(input_image)

	var out_img_uniform := RDUniform.new()
	out_img_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	out_img_uniform.binding = 1
	out_img_uniform.add_id(output_image)

	var uniform_set = UniformSetCacheRD.get_cache(shader, 0, [in_img_uniform, out_img_uniform])

	var push_constants : PackedByteArray = PackedByteArray()
	push_constants.resize(16)
	push_constants.encode_s32(0, scale)

	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_constants, 16)
	rd.compute_list_dispatch(compute_list, groups.x, groups.y, groups.z)
	rd.compute_list_end()
