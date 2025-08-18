shader_type canvas_item;

uniform float edge_fade_width : hint_range(0.0, 0.5) = 0.2;
uniform float overall_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    // Get the original texture color
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Calculate distance from edges for rectangular fade
    float dist_from_left = UV.x;
    float dist_from_right = 1.0 - UV.x;
    float dist_from_top = UV.y;
    float dist_from_bottom = 1.0 - UV.y;
    
    // Find the minimum distance to any edge
    float min_dist = min(min(dist_from_left, dist_from_right), min(dist_from_top, dist_from_bottom));
    
    // Create smooth fade based on distance from edge
    float alpha_mask = smoothstep(0.0, edge_fade_width, min_dist);
    
    // Apply both the edge mask and overall fade to the texture's alpha
    // Combine the effects by multiplying them
    COLOR = vec4(tex_color.rgb, tex_color.a * alpha_mask * overall_alpha);
}