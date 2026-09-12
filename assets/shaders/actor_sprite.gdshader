shader_type canvas_item;
render_mode unshaded;

// Status colouring for actor sprites. `tint` multiplies (chill, burn, boss
// phase); `flash` blends the whole silhouette towards `flash_color` for hit
// flashes and telegraphs, which a plain modulate cannot do.

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb *= tint.rgb;
	c.a *= tint.a;
	c.rgb = mix(c.rgb, flash_color.rgb, flash);
	COLOR = c;
}
