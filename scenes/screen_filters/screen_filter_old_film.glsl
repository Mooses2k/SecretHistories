#[compute]
// Port of the 3.x old film screen filter, origin/main
// resources/shaders/old_film/old_film.shader (MIT, see
// resources/shaders/old_film/old_film_license.txt). Tuning constants are the
// material values from origin/main resources/shaders/old_film/old_film.tres.

#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D SCREEN_COLOR_IMAGE;
layout(set = 1, binding = 0) uniform sampler2D GRAIN_TEX;
layout(set = 1, binding = 1) uniform sampler2D VIGNETTE_TEX;

layout(push_constant, std430) uniform PARAMS_TYPE {
	float time;
} PARAMS;

// old_film.tres material values from origin/main
const vec3 BASE_COLOR = vec3(0.984314, 0.619608, 0.235294);
const float GRAIN_STRENGTH = 0.1;
const float FPS = 12.0;
const float STRETCH = 0.5;
const float FLASHING = 0.001;

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

float make_grain(float time, vec2 uv) {
	vec2 ofs = vec2(
		sin(41.0 * time * sin(time * 123.0)),
		sin(27.0 * time * sin(time * 312.0))
	);
	return texture(GRAIN_TEX, (uv + mod(ofs, vec2(1.0, 1.0))) * STRETCH).r;
}

void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(SCREEN_COLOR_IMAGE);
	if (any(greaterThanEqual(pos, size))) {
		return;
	}

	vec4 color_sample = imageLoad(SCREEN_COLOR_IMAGE, pos);
	vec3 srgb = linear_to_srgb_gamma(color_sample.rgb);

	vec2 uv = (vec2(pos) + vec2(0.5)) / vec2(size);
	float v = dot(srgb, vec3(0.33333, 0.33333, 0.33333));
	v = sqrt(v);

	float frame = 1.0 / FPS;
	float grain_time = PARAMS.time - mod(PARAMS.time, frame);
	float g = make_grain(grain_time, uv);
	g = max(g, make_grain(grain_time + frame, uv) * 0.5);
	g = max(g, make_grain(grain_time + frame * 2.0, uv) * 0.25);

	vec3 col = BASE_COLOR * v - vec3(g) * GRAIN_STRENGTH;
	col *= texture(VIGNETTE_TEX, uv).r;
	float ft = PARAMS.time * 0.002;
	col += vec3(sin(75.0 * ft * sin(ft * 123.0))) * FLASHING;

	color_sample.rgb = srgb_gamma_to_linear(col);
	imageStore(SCREEN_COLOR_IMAGE, pos, color_sample);
}
