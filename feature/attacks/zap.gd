class_name Zap
extends Node2D

## A beam from where the cast starts to where the caster is pointing, landing
## the instant it is cast: nothing is in flight, so there is nothing to dodge
## and no wait between the press and the hit. `Attacks._zap` decides where it
## ends — the cursor, the beam's reach, or the first wall on the way — and this
## strikes what is on the line, nearest first, and then stays only as long as
## the picture needs. `graphics/views/zap_view.gd` draws it.

## Half the beam's width at size 1: how far to either side of the line a hit
## reaches. SIZE widens it, the way it widens an arc.
const HALF_WIDTH := 6.0
## How long the beam is on screen. Its work is done on its first frame.
const LIFE := 0.14

var payload: Payload
var team: int = 0
var attacker: Actor = null
var room = null
var from: Vector2
## Where the beam ends. Set by whoever spawns it, and pulled back to the last
## target struck when the strikes run out before the far end — the beam is
## spent there, the way a bolt is.
var to: Vector2
var life: float = LIFE
var max_life: float = LIFE
var half_width: float = HALF_WIDTH

func setup(p: Payload, start: Vector2, end_pos: Vector2, t: int, atk: Actor, rm) -> void:
	payload = p
	team = t
	attacker = atk
	room = rm
	from = start
	to = end_pos
	half_width = HALF_WIDTH * p.size
	position = Vector2.ZERO

func _ready() -> void:
	_strike()

## Every target on the line, nearest the start first. A beam is spent target by
## target the way a bolt is: without PIERCE the first thing on it takes the
## whole strike, and the beam ends there.
func _strike() -> void:
	var span := to - from
	var length := span.length()
	if length < 0.01:
		return
	var dir := span / length
	var on_line: Array = []
	for a in Attacks.targets(team):
		var along: float = clampf((a.global_position - from).dot(dir), 0.0, length)
		if (from + dir * along).distance_to(a.global_position) <= half_width + a.hurt_radius:
			on_line.append([along, a])
	on_line.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var hits_left := 1 + payload.pierce
	for entry in on_line:
		if hits_left <= 0:
			break
		var a: Actor = entry[1]
		Attacks.resolve_hit(payload, a, a.global_position, dir, attacker, room, team)
		hits_left -= 1
		if hits_left <= 0:
			to = from + dir * float(entry[0])

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
