/* 
This shader is under MIT license. Feel free to use, improve and 
change this shader according to your needs and consider sharing 
the modified result to godotshaders.com.
*/

shader_type spatial;
render_mode unshaded;

uniform int pixelSize = 4;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void vertex()
{
	POSITION = vec4(VERTEX.xy, -1.0, 1.0);
}


void fragment()
{
	
	ivec2 size = textureSize(SCREEN_TEXTURE, 0);
	
	int xRes = size.x;
	int yRes = size.y;
	
	float xFactor = float(xRes) / float(pixelSize);
	float yFactor = float(yRes) / float(pixelSize);
	
	float grid_uv_x = round(SCREEN_UV.x * xFactor) / xFactor;
	float grid_uv_y = round(SCREEN_UV.y * yFactor) / yFactor;
	
	vec4 text = texture(SCREEN_TEXTURE, vec2(grid_uv_x, grid_uv_y));
	
//	COLOR = text;
	ALBEDO = text.rgb;
}