shader_type canvas_item;
render_mode unshaded, blend_add;

#include "res://graphics/assets/shaders/lighting.gdshaderinc"

// One lamp (graphics/lamp.gd), drawn the way aarthificial's deferred lights
// are: as a mesh over everything it can reach — the square round its circle —
// that looks up what the world has already drawn under each of its pixels and
// adds that colour, lit, to the picture. Light adds, so every lamp is its own
// pass over the same two textures and none has to know of another.
//
// How bright a pixel is under it is the video's four things multiplied: how
// bright the lamp is; how far off the pixel is; how far off the way the lamp
// points it is, for a lamp that does not shine all round; and whether the
// surface there faces the lamp at all, which is what the normals are for.
// Times the lamp's colour, that is the light; times the colour the world drew
// there, what is added. A pixel that gives its own light takes none.
//
// And the video's volume: a share of the light added whatever is under it, as
// fog or dust in front of the picture would catch it, so a lamp shows in
// empty air. What a surface faces is nothing to the air in front of it, so
// the normals are left out of that share.
//
// A shadow is not a fifth thing to multiply by. A pixel in this lamp's shadow
// is not drawn at all, the way the video's stencil test drops it: neither
// the surface there nor the air in front of it is lit. The video marks
// shadows in the stencil buffer; a canvas has none to write to, so they are
// marked in a picture of their own (shadow.gdshader), one of its colours to
// a lamp.
//
// Everything is read by whole pixels: every buffer is on the picture's grid.

uniform sampler2D base : filter_nearest, repeat_disable;     // the world's colours
uniform sampler2D normals : filter_nearest, repeat_disable;  // and how it faces (lighting.gdshaderinc)
uniform sampler2D shade : filter_nearest, repeat_disable;    // where the lamps that throw shadows do not reach
uniform vec3 channel = vec3(0.0);  // which of `shade`'s colours is this lamp's; none for a lamp that throws no shadow
uniform vec3 tint = vec3(1.0);
uniform float energy = 1.0;
uniform float inner = 0.0;         // the share of its reach it is at its brightest over
uniform float falloff = 2.0;       // how fast it dims past that: 1 a straight line down to nothing at its reach
uniform vec2 aim = vec2(1.0, 0.0); // the way it points
uniform float spread = 4.0;        // half the angle it opens to, in radians: anything from PI up is all round
uniform float soft = 0.5;          // the share of that it fades toward its edge over
uniform float volume = 0.0;        // how much of it the air in front of the picture catches
uniform float close = 0.05;        // the share of its reach inside which what a surface faces counts for less

// Where this pixel is from the lamp: 1 at its reach.
varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	ivec2 here = ivec2(FRAGCOORD.xy);
	float far = length(local);
	if (far >= 1.0 || dot(texelFetch(shade, here, 0).rgb, channel) > 0.5) {
		discard;
	}
	vec2 out_from_it = local / max(far, 0.0001);
	float lit = energy * pow(clamp((1.0 - far) / max(1.0 - inner, 0.0001), 0.0, 1.0), falloff);
	if (spread < 3.1415) {
		float off = acos(clamp(dot(out_from_it, aim), -1.0, 1.0));
		lit *= 1.0 - smoothstep(spread * (1.0 - soft), spread, off);
	}
	vec4 surface = texelFetch(normals, here, 0);
	vec2 facing = facing_of(surface);
	// Right under a lamp the way to it turns right round from one pixel to the
	// next, so what a surface faces fades out there.
	float counts = length(facing) * clamp(far / max(close, 0.0001), 0.0, 1.0);
	float faced = 1.0;
	if (counts > 0.0) {
		faced = 1.0 - counts * (1.0 - clamp(dot(-out_from_it, normalize(facing)), 0.0, 1.0));
	}
	vec3 colour = texelFetch(base, here, 0).rgb;
	COLOR = vec4(tint * lit * (colour * faced * (1.0 - glow_of(surface)) + volume), 1.0);
}
