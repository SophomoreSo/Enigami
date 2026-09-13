class_name DashSlash
extends Node2D

## Carries the attacker along a line and cuts everything on the way. The auto
## variant picks its own destination behind the nearest visible enemy.

var payload: Payload
var team: int = 0
var attacker: Actor = null
var room = null
var from: Vector2
var to: Vector2
var life: float = 0.16
var max_life: float = 0.16
var _hit: Array = []
var thickness: float = 20.0

func setup(p: Payload, start: Vector2, end_pos: Vector2, t: int, atk: Actor, rm) -> void:
	payload = p
	team = t
	attacker = atk
	room = rm
	from = start
	to = end_pos
	thickness = 20.0 * p.size
	position = Vector2.ZERO

func _ready() -> void:
	_cut()

func _cut() -> void:
	var hits_left := 1 + payload.pierce
	for a in Attacks.targets(team):
		if hits_left <= 0:
			break
		if _hit.has(a):
			continue
		if Geometry2D.get_closest_point_to_segment(a.global_position, from, to).distance_to(a.global_position) <= thickness + a.hurt_radius:
			_hit.append(a)
			var dir: Vector2 = (to - from).normalized()
			Attacks.resolve_hit(payload, a, a.global_position, dir, attacker, room, team)
			hits_left -= 1
	if attacker != null and is_instance_valid(attacker):
		attacker.global_position = to
		# Arriving does not carry the fall that got you here. The lunge sets
		# where you end up, so letting the old descent through would snatch you
		# straight back down out of it; gravity builds again from zero instead.
		# (The DASH component needs no such thing — it overwrites velocity.)
		attacker.velocity.y = 0.0
		if attacker.has_method("on_dashed"):
			attacker.on_dashed()

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
