class_name DashSlashView
extends Node2D

## The line a lunge cut, thinning as it fades.

var cut: DashSlash

func _ready() -> void:
	cut = get_parent() as DashSlash
	z_index = 46

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if cut == null or not is_instance_valid(cut):
		return
	var t := clampf(cut.life / cut.max_life, 0.0, 1.0)
	var c := Style.element_color(cut.payload)
	c.a = t
	draw_line(cut.from, cut.to, c, cut.thickness * t * 0.8)
	draw_circle(cut.to, cut.thickness * 0.5 * t, c)
