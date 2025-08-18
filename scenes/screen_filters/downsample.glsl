#[compute]
// Based on https://godotshaders.com/shader/ps1-post-processing/ (CC0)

#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set=0, binding = 0) uniform image2D IN_IMG;
layout(rgba16f, set=0, binding = 1) uniform image2D OUT_IMG;

layout(push_constant, std430) uniform PARAMS_TYPE {
    int scale;
} PARAMS;

void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    ivec2 in_size = imageSize(IN_IMG);
    ivec2 out_size = imageSize(OUT_IMG);
    if (any(greaterThanEqual(pos, out_size))) {
        return;
    }

    float count = 0.0;
    vec4 color = vec4(0.0);

    ivec2 base_pos = pos * PARAMS.scale;

    for (int j = base_pos.y; j < min(base_pos.y + PARAMS.scale, in_size.y); j++) {
        for (int i = base_pos.x; i < min(base_pos.x + PARAMS.scale, in_size.x); i++) {
            color += imageLoad(IN_IMG, ivec2(i, j));
            count += 1.0;
        }
    }

    color /= count;
    imageStore(OUT_IMG, pos, color);
}