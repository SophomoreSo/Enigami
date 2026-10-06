shader_type canvas_item;
render_mode unshaded, blend_add, skip_vertex_transform;

// The shadow one lamp throws off the edges of what stands in its light
// (graphics/shadow_caster.gd), after aarthificial's deferred lights and the
// shadow meshes of Unity's 2D renderer it takes them from: every edge is a
// strip with no width, two of its corners on the edge and two more on top of
// them, and all four know which way the edge faces. Here, for an edge that
// faces away from the lamp, the second two are pushed out from the lamp
// further than it reaches — and the strip is the shadow that edge throws.
//
// The video draws each caster's whole mesh, counts in the stencil buffer how
// many cover a pixel, and takes the caster's own sprite away again, so a
// thing is lit across its own face and dark only in another's shadow. The
// edges alone come to the same picture and need no counting: a strip starts
// at the edge the light leaves the thing by, so the thing itself is never in
// its own shadow, and a pixel is dark if any strip covers it at all.
//
// A canvas has no stencil buffer to mark, so the mark is a colour of a
// picture of its own (`Lighting`): one of its three to a lamp, added, so
// three lamps share a picture and none touches another's.

uniform vec2 light;                 // where the lamp is, in the world
uniform float reach = 4096.0;       // how far an edge's shadow is thrown: past anything the lamp could light
uniform vec3 channel = vec3(1.0, 0.0, 0.0);

void vertex() {
	vec2 at = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	// The way the edge faces, which a caster keeps where a picture's corner
	// would keep its place in the texture; and in red, whether this corner is
	// one of the two that go.
	vec2 facing = normalize(mat2(MODEL_MATRIX[0].xy, MODEL_MATRIX[1].xy) * UV);
	vec2 from = at - light;
	if (COLOR.r > 0.5 && dot(-from, facing) < 0.0) {
		at += from / max(length(from), 0.0001) * reach;
	}
	VERTEX = at;
}

void fragment() {
	COLOR = vec4(channel, 1.0);
}
