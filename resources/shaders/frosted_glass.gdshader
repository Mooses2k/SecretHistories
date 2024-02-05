shader_type spatial;

uniform sampler2D distortion;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 d = texture(distortion, UV).xy - vec2(0.5);
	ALBEDO = texture(SCREEN_TEXTURE, SCREEN_UV + d).rgb;
}
