shader_type canvas_item;
render_mode unshaded;

// A sprite whose frames are painted in coordinates rather than colours.
//
// Each frame pixel's red and green are the column and row of a pixel in the
// `skin` texture, and its alpha says whether it is drawn at all; the colour
// comes from the skin. So every frame of every animation is drawn once, in a
// palette of "which skin pixel is this", and swapping the skin reskins them
// all — see `graphics/skin/pixel_map.gd`, after aarthificial's technique.
//
// The status uniforms are the same as `actor_sprite.gdshader`'s, so an actor
// view drives both shaders the same way.

uniform sampler2D skin : filter_nearest, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 at = texture(TEXTURE, UV);
	// Bytes came through a float; put them back on whole texels, and sample
	// the middle of one so no filter ever blends two.
	vec2 texel = floor(at.rg * 255.0 + 0.5);
	vec2 size = vec2(textureSize(skin, 0));
	vec4 c = texture(skin, (texel + 0.5) / size);
	c.a *= at.a;
	c.rgb *= tint.rgb;
	c.a *= tint.a;
	c.rgb = mix(c.rgb, flash_color.rgb, flash);
	COLOR = c;
}
