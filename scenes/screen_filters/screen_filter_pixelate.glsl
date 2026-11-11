#[compute]
// Port of the 3.x pixelate screen filter, origin/main
// resources/shaders/pixelate/pixelate.shader (MIT, see
// resources/shaders/pixelate/pixelate_license.txt). pixelSize is the
// pixelate.tres material value from origin/main.

#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D SCREEN_COLOR_IMAGE;

layout(push_constant, std430) uniform PARAMS_TYPE {
	int pixel_size;
} PARAMS;

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(SCREEN_COLOR_IMAGE);
	if (any(greaterThanEqual(pos, size))) {
		return;
	}

	vec2 uv = (vec2(pos) + vec2(0.5)) / vec2(size);
	vec2 factors = vec2(size) / float(PARAMS.pixel_size);
	vec2 grid_uv = round(uv * factors) / factors;
	ivec2 grid_pos = clamp(
		ivec2(round(grid_uv * vec2(size))),
		ivec2(0),
		size - 1
	);
	imageStore(SCREEN_COLOR_IMAGE, pos, imageLoad(SCREEN_COLOR_IMAGE, grid_pos));
}
