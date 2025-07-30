#[compute]
// Based on https://godotshaders.com/shader/ps1-post-processing/ (CC0)

#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set=0, binding = 0) uniform image2D SCREEN_COLOR_IMAGE;

layout(push_constant, std430) uniform PARAMS_TYPE {
    float intensity;
    float black_threshold;
    float dithering_adjust;
    int color_depth;
    int resolution_scale;
    bool dithering;
    bool brightness_fix;
} PARAMS;

int dithering(ivec2 p) {
    const int pattern[] = {
        -4, +0, -3, +1,
        +2, -2, +3, -1,
        -3, +1, -4, +0,
        +3, -1, +2, -2
    };

    int x = p.x % 4;
    int y = p.y % 4;

    return pattern[y * 4 + x];
}

vec3 damp(vec3 value) {
    float true_threshold = PARAMS.black_threshold * 0.01;
    return value + vec3(greaterThan(value, vec3(true_threshold))) * ((1.0 / pow(2.0, float(PARAMS.color_depth))) - true_threshold * (PARAMS.dithering_adjust * (PARAMS.dithering ? 1.0 : -2.0)));
}

void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(SCREEN_COLOR_IMAGE);
    if (any(greaterThanEqual(pos, size))) {
        return;
    }
    ivec2 scaled_pos = pos / PARAMS.resolution_scale;
    ivec2 sample_pos = scaled_pos * PARAMS.resolution_scale;

    vec4 screen_sample = imageLoad(SCREEN_COLOR_IMAGE, sample_pos);
    vec3 color = screen_sample.rgb;

    if (PARAMS.brightness_fix) {
        color = damp(color);
    }
    ivec3 icolor = ivec3(round(color * 255.0));

    if (PARAMS.dithering) {
        icolor += ivec3(dithering(scaled_pos));
    }

    icolor = (icolor >> (8 - PARAMS.color_depth));

    vec4 final_sample = vec4( vec3(icolor) / float(1 << PARAMS.color_depth), screen_sample.a);
    final_sample = max(final_sample, vec4(0));
    imageStore(SCREEN_COLOR_IMAGE, pos, mix(screen_sample, final_sample, PARAMS.intensity));

}