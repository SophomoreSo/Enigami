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

func setup(p: Payload, pos: Vector2, t: int, atk: Actor, rm) -> void:
	payload = p
	position = pos
	team = t
	attacker = atk
	room = rm
	radius = 90.0 * p.size

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
