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
## would otherwise sit there spending its range a pixel at a time. It is the
## least a bolt gets: one with more range than it could fly in that time — RANGE
## stacked, on a slow weapon — is given long enough to fly it (`setup`), so this
## never cuts a shot short; it only stops one hanging about.
const LIFE := 3.0

## What a bolt whose SPEED is stacked to its limit leaves at, in pixels a
## second, whatever its weapon: across a room in a tenth of a second, which is
## as good as a beam. Short of the limit, SPEED multiplies the bolt's own pace,
## and the quickest that gets — a gun's bolt one SPEED short — is under a third
## of this, so reaching the limit is a step and not one more notch.
const LASER_SPEED := 12000.0

## HOMING. How hard one HOMING turns a bolt towards what it is after, as the
## share of the turn it makes in a second. Every one stacked turns as hard
## again, which is the difference between flying wide of a corner and taking it.
const HOMING_TURN := 5.0
## How far a homing bolt looks for something to go after.
const HOMING_SIGHT := 520.0
## A homing bolt loses pace in a turn — the harder the turn, the more — and
## that is what lets it tighten onto something it would otherwise circle. Once
## it is flying straight at what it is steering for (`HOMING_STRAIGHT`, the
## cosine of how straight) it picks the pace it left at back up, this share of
## it a second, so a bolt that has gone round a corner does not crawl the rest
## of the way. It never drops below `HOMING_SLOWEST` of that pace, or a bolt
## turned right round would stop dead and hang there.
const HOMING_REGAIN := 2.0
const HOMING_STRAIGHT := 0.98
const HOMING_SLOWEST := 0.05
## How often a homing bolt looks again at whether a wall stands between it and
## its target, and works out the way round if one does, in seconds; and how
## near a point on that way counts as reached, which has it look at once.
const REPATH := 0.08
const WAYPOINT_NEAR := 14.0
## How much room a homing bolt wants either side of a straight line before it
## calls the line clear: a line that only just misses a corner is one a bolt
## that is still turning clips on the way past.
const CLEARANCE := 8.0

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
## Where a homing bolt is steering for when a wall stands between it and its
## target: a point on the way round. `_repath` counts down to looking again.
var _waypoint: Vector2 = Vector2.ZERO
var _has_waypoint: bool = false
var _repath: float = 0.0
## The pace a homing bolt left at, which is the pace it gets back to.
var _pace: float = 0.0
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
	if p.at_limit("SPEED"):
		velocity = dir.normalized() * LASER_SPEED
	life = maxf(LIFE, range_px / maxf(velocity.length(), 1.0) * 1.25)
	hits_left = 1 + p.pierce
	homing_strength = HOMING_TURN * float(p.homing)

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_expire()
		return
	if homing_strength > 0.0:
		_home(delta)
	velocity.y += gravity * delta

	# This frame's flight, and no further than the range it has left: a bolt
	# quick enough to cover the rest of its range inside one frame — a laser
	# at any frame rate, anything fast at a slow one — still flies that rest,
	# striking what is on the way, rather than fading where it stands.
	var travel := velocity * delta
	var left := range_px - _travelled
	var spent := travel.length() >= left
	if spent:
		travel = travel.limit_length(maxf(left, 0.0))
	_travelled += travel.length()
	var hops := maxi(1, int(ceil(travel.length() / MAX_STEP)))
	var hop := travel / float(hops)
	for i in hops:
		position += hop
		if _sample():
			return
	# Out of range: the shot is spent, and says so. A bolt that simply blinked
	# out would read as the game dropping it rather than as a rule the player
	# can shoot around.
	if spent:
		Cues.at(&"impact", global_position, {"payload": payload, "kind": "fade"})
		_expire()

## HOMING: turns the bolt towards the nearest enemy — straight at it while
## nothing stands between them, and otherwise at the furthest point it can fly
## straight to on the way round the walls (`Room.path_between`). How well it
## keeps to that way is how hard it turns, which is how many HOMING are
## stacked: one knows the way and flies wide of the corners, several take them.
func _home(delta: float) -> void:
	if _pace <= 0.0:
		_pace = velocity.length()
	var t := _quarry()
	if t == null:
		# Nothing to turn for, so it is flying straight: a bolt whose quarry
		# died while it was braking for the turn does not crawl on from there.
		var now := velocity.length()
		if now > 0.01 and now < _pace:
			velocity *= minf(_pace, now + HOMING_REGAIN * _pace * delta) / now
		return
	var goal: Vector2 = t.global_position
	if room != null and not is_instance_valid(room):
		room = null
	if room != null and room.has_method("path_between") and room.has_method("clear_between"):
		_repath -= delta
		if _repath <= 0.0 or (_has_waypoint and global_position.distance_to(_waypoint) < WAYPOINT_NEAR):
			_repath = REPATH
			_has_waypoint = false
			if not room.clear_between(global_position, goal, CLEARANCE):
				_find_waypoint(goal)
		if _has_waypoint:
			goal = _waypoint
	var to := goal - global_position
	if to.length() < 0.01:
		return
	var heading := to.normalized()
	# The turn, as it has always been: blending the two velocities turns the
	# bolt and shortens it, the more the further it has to turn.
	velocity = velocity.lerp(heading * velocity.length(), clampf(homing_strength * delta, 0.0, 1.0))
	var pace := velocity.length()
	var dir := velocity / pace if pace > 0.01 else heading
	if pace < _pace and dir.dot(heading) > HOMING_STRAIGHT:
		pace = minf(_pace, pace + HOMING_REGAIN * _pace * delta)
	velocity = dir * maxf(pace, _pace * HOMING_SLOWEST)

## What a homing bolt is after: the nearest enemy within sight that it has not
## struck already. One it has passed through is not something to turn back
## for, and with PIERCE on it the bolt has somewhere else to be.
func _quarry() -> Actor:
	var best: Actor = null
	var best_d := HOMING_SIGHT
	for a: Actor in Attacks.targets(team):
		if _hit.has(a):
			continue
		var d := global_position.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best

## The furthest point on the way to `goal` that the bolt can fly straight at,
## taken as the last one before a wall first gets in the way: steering for the
## next cell along would have it wobble down a corridor it could cross in one
## line. When not even the next cell is clear — the bolt is hard against a
## wall — that cell is what it steers for, which takes it off the wall.
func _find_waypoint(goal: Vector2) -> void:
	var way: PackedVector2Array = room.path_between(global_position, goal)
	if way.is_empty():
		return
	_waypoint = way[0]
	_has_waypoint = true
	for point in way:
		if not room.clear_between(global_position, point, CLEARANCE):
			return
		_waypoint = point

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
