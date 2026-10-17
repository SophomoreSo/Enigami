class_name SummonedProjectile
extends Node2D

## A bolt summoned in the air by SUMMON PROJECTILE (`Attacks._summon_projectiles`):
## it hangs where it was called, falls under its own weight — or, carrying
## ANTI-GRAVITY, stays hanging there — strikes every enemy
## it touches once with the flow it was summoned from, comes to rest on whatever
## it lands on, and is gone LIFE seconds after it was called, wherever it is.
## Nothing here draws (`SummonedProjectileView`).

## How long it lasts from the moment it is called, in seconds.
const LIFE := 3.0
## How hard it falls, in pixels a second squared, and how fast at most.
const GRAVITY := 900.0
const MAX_FALL := 700.0
## Its size, for what it strikes and what it lands on.
const RADIUS := 8.0

var payload: Payload
var team: int = 0
var attacker: Actor = null
var room = null
var velocity := Vector2.ZERO
var life := LIFE
## Whether it has come down on something and lies there.
var resting := false
var _hit: Array = []

func setup(p: Payload, at: Vector2, t: int, atk: Actor, rm) -> void:
	payload = p
	team = t
	attacker = atk
	room = rm
	global_position = at

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if room != null and not is_instance_valid(room):
		room = null
	if not resting and payload.anti_gravity <= 0:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		var next := global_position + velocity * delta
		if room != null and room.has_method("is_solid_at") and room.is_solid_at(next + Vector2(0, RADIUS)):
			# Down on the floor: it lies on top of the cell it came down on.
			var cell_top := floorf((next.y + RADIUS) / Room.CELL) * Room.CELL
			global_position = Vector2(next.x, cell_top - RADIUS)
			velocity = Vector2.ZERO
			resting = true
			Cues.at(&"summon_landed", global_position, {"payload": payload})
		else:
			global_position = next
	for a in Attacks.targets(team):
		if _hit.has(a) or not is_instance_valid(a):
			continue
		if global_position.distance_to(a.global_position) <= RADIUS + a.hurt_radius:
			_hit.append(a)
			var dir := velocity.normalized() if velocity.length() > 1.0 else Vector2.DOWN
			Attacks.resolve_hit(payload, a, global_position, dir, attacker, room, team)

## 0..1 of its life left, for whatever draws it fading.
func life_ratio() -> float:
	return clampf(life / LIFE, 0.0, 1.0)
