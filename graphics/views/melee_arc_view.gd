class_name MeleeArcView
extends Node2D

## The sweep in front of an attacker: a filled fan that collapses inward as the
## swing runs out.

var swing: MeleeArc

func _ready() -> void:
	swing = get_parent() as MeleeArc
	z_index = 45

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if swing == null or not is_instance_valid(swing):
		return
	var t := clampf(swing.life / swing.max_life, 0.0, 1.0)
	var c := Style.element_color(swing.payload)
	c.a = t
	var pts := PackedVector2Array()
	var steps := 12
	pts.append(Vector2.ZERO)
	for i in steps + 1:
		var a := swing.aim - swing.arc * 0.5 + swing.arc * float(i) / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * swing.reach * (0.55 + 0.45 * (1.0 - t)))
	var fill := c
	fill.a = t * 0.32
	draw_colored_polygon(pts, fill)
	for i in range(1, pts.size() - 1):
		draw_line(pts[i], pts[i + 1], c, 2.5)
