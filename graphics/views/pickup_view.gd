class_name PickupView
extends Node2D

## Loot on the floor: a glow, a shape that says scrap or part, and the part's
## own glyph so it can be recognised without picking it up.

var pickup: Pickup
var _t: float = 0.0

func _ready() -> void:
	pickup = get_parent() as Pickup
	z_index = 35

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if pickup == null or not is_instance_valid(pickup):
		return
	var c := Style.pickup_color(pickup)
	var bob := sin(_t * 4.0) * 2.5
	var glow := c
	glow.a = 0.25 + 0.12 * sin(_t * 5.0)
	draw_circle(Vector2(0, bob), 14.0, glow)
	if pickup.scrap_amount > 0:
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, bob - 7), Vector2(6, bob), Vector2(0, bob + 7), Vector2(-6, bob),
		]), c)
	else:
		draw_rect(Rect2(-7, bob - 7, 14, 14), c)
		draw_rect(Rect2(-7, bob - 7, 14, 14), Color(0.05, 0.07, 0.1), false, 2.0)
		# Most part glyphs are symbols the pixel font does not have, so these keep
		# the fallback face, drawn at the buffer's size like all other world text.
		PixelCamera.draw_text(self, Vector2(0, bob + 4), Style.component_glyph(pickup.component_id),
			Color(0.05, 0.07, 0.1), Color(0, 0, 0, 0), 5, ThemeDB.fallback_font)
