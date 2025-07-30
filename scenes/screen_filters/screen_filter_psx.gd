extends CompositorEffect
class_name ScreenFilterPSX

# TODO: optimize with specialization constants
# TODO: Fix race conditions in the shader
const SCREEN_FILTER_PSX : RDShaderFile = preload("res://scenes/screen_filters/screen_filter_psx.glsl")
const LOCAL_GROUP_SIZE := Vector3i(8, 8, 1)
const PUSH_CONSTANT_ELEMENT_COUNT = 7

@export_range(1, 8, 1) var color_depth : int = 5;
@export var dithering : bool = false
@export var resolution_scale : int = 4

@export var brightness_correct : bool = true
@export_range(0.0, 0.51) var pitch_black_threshold : float = 0.116;
@export var dithering_adjust : float = 10.0;

@export_range(0.0, 1.0, 0.01) var intensity : float = 1.0;

var shader : RID
var pipeline : RID

func _init() -> void:
	var rd : RenderingDevice = RenderingServer.get_rendering_device()
	shader = rd.shader_create_from_spirv(SCREEN_FILTER_PSX.get_spirv())
	assert(shader.is_valid())
	pipeline = rd.compute_pipeline_create(shader)
	assert(pipeline.is_valid())

func _render_callback(p_effect_callback_type: int, render_data: RenderData) -> void:
	if not p_effect_callback_type == effect_callback_type: return

	var buffers : RenderSceneBuffersRD = render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if not is_instance_valid(buffers) : return

	var rd : RenderingDevice = RenderingServer.get_rendering_device()

	var buffer_size : Vector2i = buffers.get_internal_size()
	# divide by local group size, rounding up
	var groups : Vector3i = (
		Vector3i(
			buffer_size.x,
			buffer_size.y,
			1
		) - Vector3i.ONE
	) / LOCAL_GROUP_SIZE + Vector3i.ONE

	var push_constants : PackedByteArray = PackedByteArray()
	push_constants.resize( ceili(PUSH_CONSTANT_ELEMENT_COUNT * 4 / 16.0) * 16);
	push_constants.encode_float(0*4, intensity)
	push_constants.encode_float(1*4, intensity)
	push_constants.encode_float(2*4, dithering_adjust)
	push_constants.encode_s32(3*4, color_depth)
	push_constants.encode_s32(4*4, resolution_scale)
	push_constants.encode_s32(5*4, 1 if dithering else 0)
	push_constants.encode_s32(6*4, 1 if brightness_correct else 0)

	var view_count = buffers.get_view_count()
	for i : int in view_count:
		var screen_color_image = buffers.get_color_layer(i)

		var screen_color_image_uniform : RDUniform = RDUniform.new()
		screen_color_image_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		screen_color_image_uniform.binding = 0
		screen_color_image_uniform.add_id(screen_color_image)

		var uniform_set = UniformSetCacheRD.get_cache(shader, 0, [screen_color_image_uniform])

		var compute_list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
		rd.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())
		rd.compute_list_dispatch(compute_list, groups.x, groups.y, groups.z)
		rd.compute_list_end()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		var rd : RenderingDevice = RenderingServer.get_rendering_device()
		if shader.is_valid():
			rd.free_rid(shader)
