class_name SummonedProjectileView
extends Node2D

## A summoned bolt (`SummonedProjectile`): a glowing orb in its flow's colour,
## with a ring round it while it hangs and falls, fading out over the last of
## its life.

const FADE := 0.4

var bolt: SummonedProjectile

func _ready() -> void:
	bolt = get_parent() as SummonedProjectile
	z_index = 45
	material = Lighting.glow()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if bolt == null or not is_instance_valid(bolt):
		return
	var left := bolt.life
	var a := clampf(left / FADE, 0.0, 1.0)
	var c := Style.element_color(bolt.payload)
	c.a = a
	draw_circle(Vector2.ZERO, SummonedProjectile.RADIUS, c)
	draw_circle(Vector2.ZERO, SummonedProjectile.RADIUS * 0.45, Color(1, 1, 1, a))
	if not bolt.resting:
		draw_arc(Vector2.ZERO, SummonedProjectile.RADIUS + 4.0, 0, TAU, 20, Color(c.r, c.g, c.b, a * 0.5), 2.0)
