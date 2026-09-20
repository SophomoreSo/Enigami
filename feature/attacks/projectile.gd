class_name Projectile
extends Node2D

## A travelling bolt. Collision is resolved analytically against actor radii and
## the room's solid grid, so attacks need no physics bodies of their own.
## `graphics/views/projectile_view.gd` draws it and keeps its own trail.

## Longest hop a bolt may take before its collision is sampled again. Walls are
## a 32px grid and a target only a few pixels across, so a fast bolt has to be
## walked in pieces: sampled once a frame, a shot carrying SPEED parts steps
## clean over a one-cell platform and out the far side of whatever it was aimed
## at. The hops cost nothing — even the fastest build needs a handful.
const MAX_STEP := 12.0

## How long a bolt may stay in the air whatever it is doing. Range is what
## actually ends a shot now — see `Payload.range_px` — and this is the backstop
## under it: a bolt that is barely moving, or one arcing at the top of a lob,
## would otherwise sit there spending its range a pixel at a time. It is set
## past what the slowest bolt in the game needs to fly its longest range, so it
## never cuts a shot short; it only stops one hanging about.
const LIFE := 3.0

var payload: Payload
var velocity: Vector2 = Vector2.RIGHT * 400.0
var team: int = 0
var attacker: Actor = null
var room = null
var radius: float = 5.0
## How far this bolt carries before it fades, taken off the payload at spawn so
## nothing has to ask a payload that may be gone.
var range_px: float = Payload.BASE_RANGE
var life: float = LIFE
var hits_left: int = 1
var gravity: float = 0.0
var homing_strength: float = 0.0
var reverse_at: float = -1.0
var _reversed: bool = false
var _hit: Array = []
## How far this bolt has flown, against `range_px`.
var _travelled: float = 0.0

func setup(p: Payload, pos: Vector2, dir: Vector2, t: int, atk: Actor, rm) -> void:
	payload = p
	position = pos
	team = t
	attacker = atk
	room = rm
	radius = 5.0 * p.size
	range_px = maxf(p.range_px, 1.0)
	velocity = dir.normalized() * 420.0 * p.speed
	hits_left = 1 + p.pierce
	homing_strength = 5.0 if p.homing else 0.0
	if p.reverse:
		reverse_at = 0.35

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_expire()
		return
	if reverse_at > 0.0:
		reverse_at -= delta
		if reverse_at <= 0.0 and not _reversed:
			_reversed = true
			velocity = -velocity
	if homing_strength > 0.0:
		var t := Attacks.nearest_target(global_position, team, 520.0)
		if t != null:
			var want := (t.global_position - global_position).normalized() * velocity.length()
			velocity = velocity.lerp(want, clampf(homing_strength * delta, 0.0, 1.0))
	velocity.y += gravity * delta

	# Out of range: the shot is spent, and says so. A bolt that simply blinked
	# out would read as the game dropping it rather than as a rule the player
	# can shoot around.
	var travel := velocity * delta
	_travelled += travel.length()
	if _travelled >= range_px:
		Cues.at(&"impact", global_position, {"payload": payload, "kind": "fade"})
		_expire()
		return
	var hops := maxi(1, int(ceil(travel.length() / MAX_STEP)))
	var hop := travel / float(hops)
	for i in hops:
		position += hop
		if _sample():
			return

## One collision sample where the bolt is standing. Returns true once the bolt
## is gone, so the caller stops walking it.
func _sample() -> bool:
	# The room a bolt was fired in can be torn down under it — walking through
	# a door frees one room and builds the next — and a reference to a freed
	# node still reads as non-null, so asking it anything at all is an error
	# rather than a false. Dropped here, a stray bolt stops testing itself
	# against walls that no longer exist and simply runs out.
	if room != null and not is_instance_valid(room):
		room = null
	if room != null and room.has_method("is_solid_at") and room.is_solid_at(global_position):
		Cues.at(&"impact", global_position, {"payload": payload, "kind": "wall"})
		queue_free()
		return true
	if room != null and room.has_method("out_of_bounds") and room.out_of_bounds(global_position):
		queue_free()
		return true

	for a in Attacks.targets(team):
		if _hit.has(a):
			continue
		if global_position.distance_to(a.global_position) <= radius + a.hurt_radius:
			_hit.append(a)
			Attacks.resolve_hit(payload, a, global_position, velocity.normalized(), attacker, room, team)
			hits_left -= 1
			if hits_left <= 0:
				Cues.at(&"impact", global_position, {"payload": payload, "kind": "spent"})
				queue_free()
				return true
	return false

func _expire() -> void:
	queue_free()
