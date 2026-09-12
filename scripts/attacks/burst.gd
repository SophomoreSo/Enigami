class_name AreaBurst
extends Node2D

## An expanding ring that damages each target once as the edge passes it.

var payload: Payload
var team: int = 0
var attacker: Actor = null
var room = null
var radius: float = 90.0
var life: float = 0.28
var max_life: float = 0.28
var _hit: Array = []
var color: Color = Color(0.98, 0.7, 0.3)

func setup(p: Payload, pos: Vector2, t: int, atk: Actor, rm) -> void:
	payload = p
	position = pos
	team = t
	attacker = atk
	room = rm
	radius = 90.0 * p.size
	color = Projectile._element_color(p)
	z_index = 42
	Fx.shake(6.0)
	Audio.play("explode")

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var t := 1.0 - life / max_life
	var r := radius * t
	for a in Attacks.targets(team):
		if _hit.has(a):
			continue
		if global_position.distance_to(a.global_position) <= r + a.hurt_radius:
			_hit.append(a)
			var dir: Vector2 = (a.global_position - global_position).normalized()
			Attacks.resolve_hit(payload, a, a.global_position, dir, attacker, room, team)
	queue_redraw()

func _draw() -> void:
	var t := 1.0 - life / max_life
	var c := color
	c.a = (1.0 - t) * 0.8
	draw_circle(Vector2.ZERO, radius * t, Color(c.r, c.g, c.b, c.a * 0.25))
	draw_arc(Vector2.ZERO, radius * t, 0, TAU, 36, c, 3.0)
