shader_type canvas_item;
render_mode unshaded, blend_disabled;

#include "res://graphics/assets/shaders/glazing.gdshaderinc"

// The picture with the glass in it (graphics/glazing.gd): the last thing done
// to it before it is shown, over all of it, reading the picture as it came —
// lit, or as drawn — and the glazing's marks under each of its pixels.
//
// Where there is no glass the picture is as it came. Under clear glass, what
// is behind the glass is what the picture already has there, and it is shown
// a little tinted. Under a mirror, what the picture has across the mirror's
// face (glass_to) is shown over what the mirror itself was drawn as: most of
// it at the face, less the deeper into the mirror the pixel lies, and nothing
// past `mirror_deep`, or for what is off the picture altogether. Whatever stands
// in front of the glass has wiped its mark out, and is shown as it is.
//
// Everything is read by whole pixels: both buffers are on the picture's grid.

uniform sampler2D picture : filter_nearest, repeat_disable;  // the picture as it came
uniform sampler2D marks : filter_nearest, repeat_disable;    // where the glass is (glazing.gdshaderinc)
// What clear glass does to what is seen through it; what a mirror does to what
// it shows, how much of that it shows at its face, and how deep into it, in
// pixels, that has faded to nothing. Set by the glazing (Glazing.CLEAR_TINT and
// the rest).
uniform vec3 clear_tint = vec3(1.0);
uniform vec3 mirror_tint = vec3(1.0);
uniform float mirror_shows = 0.0;
uniform float mirror_deep = 1.0;

void fragment() {
	ivec2 here = ivec2(FRAGCOORD.xy);
	vec3 seen = texelFetch(picture, here, 0).rgb;
	vec4 mark = texelFetch(marks, here, 0);
	float cover = glass_cover(mark);
	vec3 glazed = seen;
	if (cover > 0.0) {
		if (glass_mirror(mark)) {
			vec2 to = glass_to(mark);
			ivec2 size = textureSize(picture, 0);
			ivec2 from = here + ivec2(to);
			float shows = 0.0;
			if (to != vec2(0.0) && all(greaterThanEqual(from, ivec2(0))) && all(lessThan(from, size))) {
				float deep = (max(abs(to.x), abs(to.y)) - 1.0) * 0.5;
				shows = mirror_shows * (1.0 - clamp(deep / mirror_deep, 0.0, 1.0));
			}
			vec3 shown = texelFetch(picture, clamp(from, ivec2(0), size - ivec2(1)), 0).rgb;
			glazed = mix(seen, shown * mirror_tint, shows);
		} else {
			glazed = seen * clear_tint;
		}
	}
	COLOR = vec4(mix(seen, glazed, cover), 1.0);
}
