/* 
The shader code and all code snippets in this post are under CC0 license and can be used freely 
without the author's permission. 
Adapted from: https://godotshaders.com/shader/color-reduction-and-dither/
*/

shader_type spatial;
render_mode unshaded;

uniform float colors : hint_range(1.0, 16.0);
uniform float dither : hint_range(0.0, 0.5);


void vertex()
{
	POSITION = vec4(VERTEX.xy, -1.0, 1.0);
}


void fragment()
{
	vec4 color = texture(SCREEN_TEXTURE, SCREEN_UV);
	
//	float a = floor(mod(UV.x / TEXTURE_PIXEL_SIZE.x, 2.0));
//	float b = floor(mod(UV.y / TEXTURE_PIXEL_SIZE.y, 2.0));	
//	float c = mod(a + b, 2.0);
	float c = mod(2.0, 2.0);
	
	ALBEDO.r = (round(color.r * colors + dither) / colors) * c;
	ALBEDO.g = (round(color.g * colors + dither) / colors) * c;
	ALBEDO.b = (round(color.b * colors + dither) / colors) * c;
	c = 1.0 - c;
	ALBEDO.r += (round(color.r * colors - dither) / colors) * c;
	ALBEDO.g += (round(color.g * colors - dither) / colors) * c;
	ALBEDO.b += (round(color.b * colors - dither) / colors) * c;
}