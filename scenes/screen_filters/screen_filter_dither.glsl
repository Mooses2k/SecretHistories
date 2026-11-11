#[compute]
// Port of the 3.x dither screen filter, origin/main
// resources/shaders/dither/shader/dither.shader (MIT, SamBigos, see
// resources/shaders/dither/dither_license.txt). Parameters and textures are
// the dither.tres material values from origin/main.

#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D SCREEN_COLOR_IMAGE;
layout(set = 1, binding = 0) uniform sampler2D DITHER_TEX;
layout(set = 1, binding = 1) uniform sampler2D COLOR_TEX;

layout(push_constant, std430) uniform PARAMS_TYPE {
	int bit_depth;
	float contrast;
	float offset;
	int dither_size;
} PARAMS;

// Equations from https://en.wikipedia.org/wiki/SRGB#Transfer_function_(%22gamma%22)
// Converts a color from linear light gamma to sRGB gamma
vec3 linear_to_srgb_gamma(vec3 linear) {
	vec3 threshold = step(vec3(0.0031308), linear.rgb);
	vec3 above = 1.055 * pow(linear.rgb, vec3(1.0 / 2.4)) - vec3(0.055);
	vec3 below = linear.rgb * 12.92;
	return mix(below, above, threshold);
}

// Converts a color from sRGB gamma to linear light gamma
vec3 srgb_gamma_to_linear(vec3 srgb) {
	vec3 threshold = step(vec3(0.04045), srgb);
	vec3 above = pow((srgb + vec3(0.055)) / 1.055, vec3(2.4));
	vec3 below = srgb / 12.92;
	return mix(below, above, threshold);
}

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(SCREEN_COLOR_IMAGE);
	if (any(greaterThanEqual(pos, size))) {
		return;
	}

	// Sample the screen texture at the desired output resolution (according to
	// PARAMS.dither_size): this pixelates the output before the dither.
	vec2 screen_size = vec2(size) / float(PARAMS.dither_size);
	vec2 uv = (vec2(pos) + vec2(0.5)) / vec2(size);
	vec2 sample_uv = floor(uv * screen_size) / screen_size;
	ivec2 sample_pos = clamp(
		ivec2(round(sample_uv * vec2(size))),
		ivec2(0),
		size - 1
	);
	vec4 color_sample = imageLoad(SCREEN_COLOR_IMAGE, pos);
	vec3 screen_col = linear_to_srgb_gamma(imageLoad(SCREEN_COLOR_IMAGE, sample_pos).rgb);

	// Pixel luminosity (https://stackoverflow.com/questions/596216/formula-to-determine-brightness-of-rgb-color)
	float lum = (screen_col.r * 0.299) + (screen_col.g * 0.587) + (screen_col.b * 0.114);

	// Adjust with contrast and offset parameters
	lum = (lum - 0.5 + PARAMS.offset) * PARAMS.contrast + 0.5;
	lum = clamp(lum, 0.0, 1.0);

	// Reduce luminosity bit depth to give a more banded visual
	float bits = float(PARAMS.bit_depth);
	lum = floor(lum * bits) / bits;

	// Dither between the two palette colours adjacent to the pixel luminosity:
	// find the band lum falls into, then pick the upper or lower bound colour
	// using the dither texture.
	ivec2 col_size = textureSize(COLOR_TEX, 0);
	col_size /= col_size.y;
	float col_x = float(col_size.x) - 1.0; // colour boundaries is 1 less than the number of colour bands
	float col_texel_size = 1.0 / col_x;

	lum = max(lum - 0.00001, 0.0); // keeps the floor below well-behaved at lum == 1.0
	float lum_lower = floor(lum * col_x) * col_texel_size;
	float lum_upper = (floor(lum * col_x) + 1.0) * col_texel_size;
	float lum_scaled = lum * col_x - floor(lum * col_x);

	// Map the dither texture onto the screen
	ivec2 noise_size = textureSize(DITHER_TEX, 0);
	vec2 inv_noise_size = vec2(1.0 / float(noise_size.x), 1.0 / float(noise_size.y));
	vec2 noise_uv = uv * inv_noise_size * screen_size;
	float threshold = texture(DITHER_TEX, noise_uv).r;

	// Shift the dither so min and max are not quite at 0.0 and 1.0, otherwise
	// fully dark and fully light dither patterns would never appear
	threshold = threshold * 0.99 + 0.005;

	// Lower lum_scaled means fewer pixels below the threshold use the lower
	// bound colour, and vice versa
	float ramp_val = lum_scaled < threshold ? 0.0 : 1.0;
	float col_sample = mix(lum_lower, lum_upper, ramp_val);
	vec3 final_col = texture(COLOR_TEX, vec2(col_sample, 0.5)).rgb;

	color_sample.rgb = srgb_gamma_to_linear(final_col);
	imageStore(SCREEN_COLOR_IMAGE, pos, color_sample);
}
