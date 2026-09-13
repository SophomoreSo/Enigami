class_name AreaBurstView
extends Node2D

## An expanding ring, drawn where the damage actually is: the edge passes a
## target on the frame it hits it.

var blast: AreaBurst

func _ready() -> void:
	blast = get_parent() as AreaBurst
	z_index = 42

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if blast == null or not is_instance_valid(blast):
		return
	var t := 1.0 - blast.life / blast.max_life
	var c := Style.element_color(blast.payload)
	c.a = (1.0 - t) * 0.8
	draw_circle(Vector2.ZERO, blast.radius * t, Color(c.r, c.g, c.b, c.a * 0.25))
	draw_arc(Vector2.ZERO, blast.radius * t, 0, TAU, 36, c, 3.0)
