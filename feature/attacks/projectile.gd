class_name Projectile
extends Node2D

## A travelling bolt. Collision is resolved analytically against actor radii and
## the room's solid grid, so attacks need no physics bodies of their own.
## `graphics/views/projectile_view.gd` draws it and keeps its own trail.
##
## Off a thrown weapon (`Weapons.is_thrown`) the bolt is the weapon itself — the
## rock — and it does not fade when it is done: it comes down off whatever it
## struck, or out of the end of its throw, and lies where it lands for whoever
## threw it to pick back up (`LooseRock`). The rest of a volley it went out in
## are copies of it, and those go the way any bolt does.

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
## It went from five to ten when bolts were given half the range they had: at
## the same pace, a turn twice as hard draws the same curve at half the size, so
## one HOMING still comes round onto something beside it before it is spent.
const HOMING_TURN := 10.0
## A homing bolt turns by the distance it covers, as one flying at this pace
## would turn over it, whenever it is going faster: a turn counted by time
## alone is no turn at all at laser speed, where a frame is two hundred pixels.
## A gun's bolt flies a little under it, so nothing slower turns differently.
const HOMING_PACE := 1200.0
## How far a homing bolt looks for something to go after, at the least: it
## looks as far as it has yet to fly, so one with RANGE on it goes after
## whatever it can reach, however far that is (`_quarry`).
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
## The thrown weapon this bolt is, or "": the rock, which comes down where it
## ends rather than fading. `thrower` is whose it is. A `ghost` is a copy of it
## that the same cast sent — the rest of a DUPLICATE's volley, a lap that came
## round with the rock already gone — which strikes as it does and is gone once
## it comes down: there is only the one rock.
var thrown: String = ""
var thrower: Player = null
var ghost: bool = false
## The last place the bolt stood that was open, for a rock that ends in a wall
## to come down from.
var _last_open: Vector2 = Vector2.ZERO

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
	_last_open = pos

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_expire()
		return
	if homing_strength > 0.0:
		_fly_homing(delta)
		return
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
		_last_open = global_position
	# Out of range: the shot is spent, and says so. A bolt that simply blinked
	# out would read as the game dropping it rather than as a rule the player
	# can shoot around. The rock is out of throw, not spent: it falls from
	# where it has got to.
	if spent:
		if is_rock():
			_come_down(velocity * 0.5)
			return
		Cues.at(&"impact", global_position, {"payload": payload, "kind": "fade"})
		_expire()

## A homing bolt's frame, in hops no longer than `MAX_STEP`, turning before
## each one rather than once for the frame: a laser's frame flown straight would
## take it through the corner it was turning for, or into the floor under the
## feet of whoever loosed it. Otherwise the same flight as any bolt's.
func _fly_homing(delta: float) -> void:
	var t := delta
	while t > 0.0:
		var pace := maxf(velocity.length(), 1.0)
		var step := minf(t, MAX_STEP / pace)
		_home(maxf(step, step * pace / HOMING_PACE))
		velocity.y += gravity * step
		var hop := velocity * step
		var left := range_px - _travelled
		var spent := hop.length() >= left
		if spent:
			hop = hop.limit_length(maxf(left, 0.0))
		_travelled += hop.length()
		position += hop
		if _sample():
			return
		_last_open = global_position
		if spent:
			if is_rock():
				_come_down(velocity * 0.5)
				return
			Cues.at(&"impact", global_position, {"payload": payload, "kind": "fade"})
			_expire()
			return
		t -= step

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
	var best_d := maxf(HOMING_SIGHT, range_px - _travelled)
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
	_waypoint = furthest_clear(room, global_position, way)
	_has_waypoint = true

## Where a bolt at `from` makes for, on its way to `goal`: `goal` itself when
## nothing stands between, and otherwise the furthest point on the way round it
## can fly straight to (`furthest_clear`). What AUTO-AIM points a homing bolt
## at as it goes, so it leaves along the way and not into the wall.
static func way_toward(rm, from: Vector2, goal: Vector2) -> Vector2:
	if rm == null or not is_instance_valid(rm) or not rm.has_method("path_between") \
			or rm.clear_between(from, goal, CLEARANCE):
		return goal
	var way: PackedVector2Array = rm.path_between(from, goal)
	return goal if way.is_empty() else furthest_clear(rm, from, way)

## The last point of `way` reachable from `from` in a straight line before a
## wall first gets in the way — or its first, hard against a wall.
static func furthest_clear(rm, from: Vector2, way: PackedVector2Array) -> Vector2:
	var out := way[0]
	for point in way:
		if not rm.clear_between(from, point, CLEARANCE):
			break
		out = point
	return out

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
		if is_rock():
			_come_down(_off_the_wall(), true)
			return true
		queue_free()
		return true
	if room != null and room.has_method("out_of_bounds") and room.out_of_bounds(global_position):
		if is_rock():
			_come_down(Vector2.ZERO, true)
			return true
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
				if is_rock():
					# Off whatever it struck: back the way it came a little, and
					# up, before it drops at their feet.
					_come_down(Vector2(-velocity.x * 0.25, -180.0))
					return true
				queue_free()
				return true
	return false

func _expire() -> void:
	if is_rock():
		_come_down(velocity * 0.5)
		return
	queue_free()

## Whether this bolt is the rock itself, and not a copy of it.
func is_rock() -> bool:
	return thrown != "" and not ghost

## The rock, done flying: it comes down where it is — or, off a wall, where it
## last stood in the open — moving at `moving`, and lies there for whoever
## threw it.
func _come_down(moving: Vector2, from_open: bool = false) -> void:
	LooseRock.drop(thrown, _last_open if from_open else global_position, moving, room, thrower)
	queue_free()

## How a rock comes back off the wall it has flown into: what it was crossing
## carries on, slower, and what ran into the wall turns round. Which way it ran
## in is told by whether the open place it came from is open straight across
## from where it stands — then it came down or up into the wall, onto a floor or
## a ceiling — or not, and it came at the wall side on.
func _off_the_wall() -> Vector2:
	var level := Vector2(global_position.x, _last_open.y)
	if room != null and room.has_method("is_solid_at") and not room.is_solid_at(level):
		return Vector2(velocity.x * 0.5, -velocity.y * 0.3)
	return Vector2(-velocity.x * 0.3, velocity.y * 0.3)

## Where the rock would come down if it were brought down now: for a room
## being walked out of with the rock still in the air.
func resting_place() -> Vector2:
	return _last_open
