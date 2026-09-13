class_name ProjectileView
extends Node2D

## A bolt: a lit core, and the streak of where it has just been. The trail is
## sampled here rather than stored on the bolt — it is a picture of the path,
## not a fact about it.

const TRAIL_LEN := 8

var bolt: Projectile
var color: Color = Style.NEUTRAL_ATTACK
var _trail: Array[Vector2] = []

func _ready() -> void:
	bolt = get_parent() as Projectile
	z_index = 40

func _process(_delta: float) -> void:
	if bolt == null or not is_instance_valid(bolt):
		return
	color = Style.element_color(bolt.payload)
	_trail.append(bolt.global_position)
	if _trail.size() > TRAIL_LEN:
		_trail.pop_front()
	queue_redraw()

func _draw() -> void:
	if bolt == null or not is_instance_valid(bolt):
		return
	for i in _trail.size():
		var t := float(i) / float(maxi(_trail.size(), 1))
		var c := color
		c.a = t * 0.4
		draw_circle(to_local(_trail[i]), bolt.radius * (0.3 + t * 0.7), c)
	draw_circle(Vector2.ZERO, bolt.radius, color)
	draw_circle(Vector2.ZERO, bolt.radius * 0.5, Color(1, 1, 1, 0.9))
