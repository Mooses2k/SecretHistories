#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set=0, binding = 0) uniform image2D SCREEN_COLOR_IMAGE;



layout(push_constant, std430) uniform PARAMS_TYPE {
    float intensity;
    int color_depth;
    float gamma;
} PARAMS;

// Equations from https://en.wikipedia.org/wiki/SRGB#Transfer_function_(%22gamma%22)
// Converts a color from linear light gamma to sRGB gamma
vec3 linear_to_srgb_gamma(vec3 linear)
{
    vec3 threshold = step(vec3(0.0031308), linear.rgb);
    vec3 above = 1.055*pow(linear.rgb, vec3(1.0/2.4)) - vec3(0.055);
    vec3 below = linear.rgb * 12.92;

    return mix(below, above, threshold);
}

// Converts a color from sRGB gamma to linear light gamma
vec3 srgb_gamma_to_linear(vec3 srgb)
{
    vec3 threshold = step(vec3(0.04045), srgb);
    vec3 above = pow((srgb + vec3(0.055))/1.055, vec3(2.4));
    vec3 below = srgb/12.92;

    return mix(below, above, threshold);
}

void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(SCREEN_COLOR_IMAGE);
    if (any(greaterThanEqual(pos, size))) {
        return;
    }
    
    // With srgb <-> linear conversion
    vec4 color_sample = imageLoad(SCREEN_COLOR_IMAGE, pos);
    vec3 srgb = linear_to_srgb_gamma(color_sample.rgb);
    float color_steps = float((1 << PARAMS.color_depth) - 1);
    srgb = round(srgb * color_steps) / color_steps;
    color_sample.rgb = mix(color_sample.rgb, srgb_gamma_to_linear(srgb), PARAMS.intensity);
    imageStore(SCREEN_COLOR_IMAGE, pos, color_sample);

    // without srgb <-> linear conversion
    // vec4 color_sample = imageLoad(SCREEN_COLOR_IMAGE, pos);
    // vec3 color = color_sample.rgb;
    // float color_steps = float((1 << PARAMS.color_depth) - 1);
    // color = round(color * color_steps) / color_steps;
    // color_sample.rgb = mix(color_sample.rgb, color, PARAMS.intensity);
    // imageStore(SCREEN_COLOR_IMAGE, pos, color_sample);

    // with gamma
    // vec4 color_sample = imageLoad(SCREEN_COLOR_IMAGE, pos);
    // vec3 color = pow(color_sample.rgb, vec3(1.0/PARAMS.gamma));
    // float color_steps = float((1 << PARAMS.color_depth) - 1);
    // color = round(color * color_steps) / color_steps;
    // color_sample.rgb = mix(color_sample.rgb, pow(color, vec3(PARAMS.gamma)), PARAMS.intensity);
    // imageStore(SCREEN_COLOR_IMAGE, pos, color_sample);
}