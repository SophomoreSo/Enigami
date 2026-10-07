class_name AreaBurst
extends Node2D

## An expanding ring that damages each target once as the edge passes it.

var payload: Payload
var team: int = 0
var attacker: Actor = null
var room = null
var radius: float = Attacks.BURST_RADIUS
var life: float = 0.28
var max_life: float = 0.28
var _hit: Array = []

## `reach` is how far the ring opens, and `p`'s own size of a burst when it is
## not said (`Attacks.burst_radius`). `spared` counts as struck already: the
## enemy an EXPLODE hit bursts on, which has taken that hit.
func setup(p: Payload, pos: Vector2, t: int, atk: Actor, rm, reach: float = -1.0,
		spared: Actor = null) -> void:
	payload = p
	position = pos
	team = t
	attacker = atk
	room = rm
	radius = reach if reach >= 0.0 else Attacks.burst_radius(p)
	if spared != null:
		_hit.append(spared)

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
