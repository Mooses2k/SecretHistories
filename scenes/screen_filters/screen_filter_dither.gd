extends CompositorEffect
class_name ScreenFilterDither

## Full-screen palette dither post filter: pixelated luminance bands mapped
## onto a colour palette with a threshold dither pattern. Compute port of the
## 3.x dither shader for the CompositorEffect pipeline; parameters and
## textures mirror the 3.x dither.tres material. See the license note in the
## .glsl file.

const SCREEN_FILTER_DITHER := preload("res://scenes/screen_filters/screen_filter_dither.glsl")
const DITHER_TEXTURE := preload("res://resources/shaders/dither/assets/bayer2tile16.png")
const COLOR_TEXTURE := preload("res://resources/shaders/dither/assets/palette_eeve.png")
const LOCAL_GROUP_SIZE := Vector3i(8, 8, 1)
const PUSH_CONSTANT_ELEMENT_COUNT = 4

@export_range(1, 64, 1) var bit_depth : int = 32
@export_range(0.0, 4.0, 0.01) var contrast : float = 1.0
@export_range(-2.0, 2.0, 0.01) var offset : float = 0.21
@export_range(1, 16, 1) var dither_size : int = 4

var shader : RID
var pipeline : RID
var sampler : RID
var dither_texture : RID
var color_texture : RID


func _init() -> void:
	enabled = false
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	var rd : RenderingDevice = RenderingServer.get_rendering_device()
	if rd == null:
		push_warning("ScreenFilterDither: no RenderingDevice, filter stays unusable")
		return
	shader = rd.shader_create_from_spirv(SCREEN_FILTER_DITHER.get_spirv())
	assert(shader.is_valid())
	pipeline = rd.compute_pipeline_create(shader)
	assert(pipeline.is_valid())
	sampler = rd.sampler_create(_make_sampler_state())
	dither_texture = _make_sampled_texture(rd, DITHER_TEXTURE.get_image())
	color_texture = _make_sampled_texture(rd, COLOR_TEXTURE.get_image())


func _make_sampler_state() -> RDSamplerState:
	var state := RDSamplerState.new()
	state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	return state


func _make_sampled_texture(rd : RenderingDevice, image : Image) -> RID:
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var format := RDTextureFormat.new()
	format.width = image.get_width()
	format.height = image.get_height()
	format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	return rd.texture_create(format, RDTextureView.new(), [image.get_data()])


func _render_callback(p_effect_callback_type: int, render_data: RenderData) -> void:
	if not p_effect_callback_type == effect_callback_type: return
	if not shader.is_valid(): return

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
	push_constants.encode_s32(0*4, bit_depth)
	push_constants.encode_float(1*4, contrast)
	push_constants.encode_float(2*4, offset)
	push_constants.encode_s32(3*4, dither_size)

	var view_count = buffers.get_view_count()
	for i : int in view_count:
		var screen_color_image = buffers.get_color_layer(i)

		var screen_color_image_uniform : RDUniform = RDUniform.new()
		screen_color_image_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		screen_color_image_uniform.binding = 0
		screen_color_image_uniform.add_id(screen_color_image)

		var dither_uniform : RDUniform = RDUniform.new()
		dither_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		dither_uniform.binding = 0
		dither_uniform.add_id(sampler)
		dither_uniform.add_id(dither_texture)

		var color_uniform : RDUniform = RDUniform.new()
		color_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		color_uniform.binding = 1
		color_uniform.add_id(sampler)
		color_uniform.add_id(color_texture)

		var uniform_set = UniformSetCacheRD.get_cache(shader, 1, [
			dither_uniform, color_uniform
		])

		var compute_list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set, 1)
		rd.compute_list_bind_uniform_set(compute_list, UniformSetCacheRD.get_cache(
			shader, 0, [screen_color_image_uniform]
		), 0)
		rd.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())
		rd.compute_list_dispatch(compute_list, groups.x, groups.y, groups.z)
		rd.compute_list_end()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		var rd : RenderingDevice = RenderingServer.get_rendering_device()
		if rd != null:
			if shader.is_valid():
				rd.free_rid(shader)
			if dither_texture.is_valid():
				rd.free_rid(dither_texture)
			if color_texture.is_valid():
				rd.free_rid(color_texture)
			if sampler.is_valid():
				rd.free_rid(sampler)
