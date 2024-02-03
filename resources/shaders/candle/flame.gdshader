/**************************************************************************/
/* flame.gdshader                                                         */
/**************************************************************************/
/*                                                                        */
/*                            by Alek & Niki                              */
/*                                                                        */
/**************************************************************************/
/* Copyright (c) 2023-present MonochromeBird and contributors             */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/

shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx,unshaded;

uniform float noise_seed = 0.0;

uniform vec3 top_offset = vec3(0.0, 0.0, 0.0);
uniform vec2 model_height_range = vec2(-1.0, 1.0);

uniform sampler2D noise : source_color;
uniform float noise_scale = 0.5;
uniform sampler2D texture_albedo : source_color;
uniform float timescale : hint_range(0.0, 9.0, 0.1) = 1.0;
uniform float scale = 1;
uniform sampler2D gradient : source_color;
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;

void vertex()
{
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX += VERTEX.y > ((model_height_range.x / 2.0) + (model_height_range.y / 2.0)) ? top_offset : vec3(0.0);
	VERTEX *= scale;
	VERTEX.y -= (1.0 - scale);
}

void fragment()
{
	//vec4 world_position = inverse(MODEL_MATRIX) * vec4(VERTEX, 1.0);
	float absolute_timescale = TIME * timescale;
	vec4 noise_tex = texture(noise, (UV + absolute_timescale + vec2(noise_seed*666.0)) * noise_scale);
	vec4 albedo_tex = texture(texture_albedo, (UV) + (noise_tex.r - 0.5));
	ALBEDO = texture(gradient, UV).rgb * albedo_tex.rgb;
	ALPHA = albedo_tex.r;
}