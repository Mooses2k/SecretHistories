shader_type spatial;
render_mode unshaded;


uniform sampler2D vignette;


void vertex()
{
	POSITION = vec4(VERTEX.xy, -1.0, 1.0);
}


void fragment() {
	vec3 vignette_color = texture(vignette, UV).rgb;
	// Screen texture stores gaussian blurred copies on mipmaps.
	ALBEDO.rgb = textureLod(SCREEN_TEXTURE, SCREEN_UV, (1.0 - vignette_color.r) * 4.0).rgb;
	ALBEDO.rgb *= texture(vignette, UV).rgb;
}
