shader_type spatial;
render_mode unshaded, blend_add;

// Inverse transform of the effect origin node, can be obtained with
// global_transform.affine_inverse()
uniform mat4 EFFECT_TRANSFORM = mat4(0.0);
uniform vec3 EFFECT_ORIGIN = vec3(0.0);
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;
varying mat4 CAMERA;

void vertex() {
	POSITION = vec4(VERTEX.xy, -1.0, 1.0);
	CAMERA = INV_VIEW_MATRIX;
}

float get_grid_mask(vec2 pos) {
	const float CELL_SCALE = 5.0;
	vec2 cell_coords = abs(fract(CELL_SCALE*pos) - 0.5)/CELL_SCALE;
	float dist = min(cell_coords.x, cell_coords.y);
	return smoothstep(0.02, 0.00, dist);
	
}

float get_sdf(vec3 pos, float r, float h) {
	
	pos.y -= clamp( pos.y, 0.0, h );
  	return length( pos ) - r;
}

float get_fallof_mask(vec3 pos, float r, float h, float half_width) {
	return smoothstep(half_width, -half_width, get_sdf(pos, r, h));
}

// The amount of time that it takes to fade in from black to the night vision. A value lower than 1 will result in faster fade in times and a value higher than 1 will result in longer fade in times.
uniform float fade_in_delay = 1.0;
// The amount of grain applied to the night vision.
uniform float noise_amount = 0.5;

// Only difference here is that we don't need to specify `in` in the parameter.
float hash(float n)
{
	return fract(sin(n) * 43758.5453123);
}

void fragment() {
	float depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float linear_depth = -view.z;
	vec4 world = CAMERA * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec3 world_position = world.xyz / world.w;
	
	vec3 world_dx = dFdx(world_position);
	vec3 world_dy = dFdy(world_position);
	vec3 normal = normalize(cross(world_dx, world_dy));
	
	vec3 offset = (EFFECT_TRANSFORM*vec4(world_position, 1.0)).xyz;
	float mask = get_fallof_mask(offset, 0.8, 1.3, 0.5);
//	float ring_mask = get_sdf(offset, 1.0, 1.0);
//	ring_mask = fract(4.0*ring_mask - 2.0*TIME);
//	ring_mask = smoothstep(0.4, 0.5, ring_mask)*smoothstep(0.6, 0.5, ring_mask);
	//ALBEDO = vec3(mask*ring_mask);
//	vec3 grid_mask = vec3(
//        get_grid_mask(offset.yz),
//        get_grid_mask(offset.xz),
//        get_grid_mask(offset.xy)
//    );
//	vec3 weights = abs(normal);
//    weights /= max(weights.x, max(weights.y, weights.z));
//    weights = pow(weights, vec3(8.0));
	
	vec2 i_resolution = VIEWPORT_SIZE;
	vec2 p = FRAGCOORD.xy / i_resolution;
	
	vec2 u = p * 2. - 1.;
	vec2 n = u * vec2(i_resolution.x / i_resolution.y, 1.0);
	vec3 c = texture(SCREEN_TEXTURE, p).xyz;
	
	c += sin(hash(TIME)) * 0.01;
	c += hash((hash(n.x) + n.y) * TIME) * (0.5 * noise_amount);
	c *= smoothstep(length(n * n * n * vec2(0.075, 0.4)), 1.0, 0.4);
	c *= smoothstep(0.001, 3.5 * fade_in_delay, TIME) * 1.5;
	
	c = dot(c, vec3(0.2126, 0.7152, 0.0722)) * vec3(0.2, 1.5 - hash(TIME) * 0.1, 0.4);
	
	//COLOR = vec4(c, 1.0);
	//ALBEDO = vec3(mask*dot(weights, grid_mask));
	ALBEDO = vec3(mask*c);
    //ALBEDO = vec3(mask*normal);
}