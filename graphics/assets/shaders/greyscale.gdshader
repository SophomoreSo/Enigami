shader_type canvas_item;

// Drains the colour out of the picture it is on: `amount` 0 leaves it as it
// was drawn, 1 is grey, by how bright each pixel is to the eye. The pixel
// camera lays it over the world while magic is off (`PixelCamera`, `Magic`).
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c.rgb, vec3(grey), amount), c.a);
}
