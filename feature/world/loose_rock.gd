class_name LooseRock
extends FallingThing

## The rock, lying where it came down: a thrown weapon out of hand
## (`Weapons.is_thrown`). It falls, bounces off what it meets and settles on
## the floor, and the hands that threw it pick it back up by walking over it —
## the player's own, or a monster's they are in (`Player.possess`). A monster
## with its own mind never does: it is not theirs. Until it is picked up, the
## weapon casts nothing.
##
## There is only ever the one. One whose weapon is back in hand some other way —
## a kit handed out again, at the bench or in the hideout — is not the rock any
## more, and goes.
##
## A room walked out of with it lying there keeps it (`Room.save_state`), and
## walking back in finds it where it was. `graphics/views/loose_rock_view.gd`
## draws it.
##
## One a throw ran out of speed in the air (`Projectile._fall_out`) is still
## the throw as it falls (`arm`): it strikes what it falls onto — each once,
## and none the throw had struck already — and where it first meets the rock,
## a wall on the way or the ground it comes down on, the throw goes off
## (`Attacks.land`) if it was not spent on what it struck. Then it is only a
## rock.

signal picked_up(rock: LooseRock, by: Actor)

## Half its height: the tile it is drawn with is eight pixels of the picture
## high, two of the world's each.
const RADIUS := 8.0
## How much of its speed it keeps, the other way, off what it hits; and how
## slowly it has to be coming down to stop rather than bounce.
const BOUNCE := 0.35
const REST_SPEED := 110.0
## How quickly it stops sliding once it is down.
const FRICTION := 900.0
## How close the hands have to come: touching it, give or take.
const REACH := 8.0

## Which weapon this is.
var weapon: String = "ROCK"
## Whose it is: the only hands that pick it up are this player's.
var thrower: Player = null
var _placed: bool = false
## The throw it is still, falling: what it strikes with, for which side, as
## whose blow, and what it has struck already; null once it is down.
var strikes: Payload = null
var _team: int = 0
var _attacker: Actor = null
var _hit: Array = []
var _hits_left: int = 1
## Whether it may strike its thrower: whether the throw had left their hand.
var _at_thrower: bool = false

func _init() -> void:
	radius = RADIUS

## Puts the rock `weapon` down at `at`, moving at `moving`, in `in_room` — or,
## with no room to lie in, wherever attacks are kept — for `by` to pick back
## up. What a bolt that was the rock becomes when it is done flying, and what a
## monster lets go of when the player steps out of it.
static func drop(weapon_id: String, at: Vector2, moving: Vector2, in_room, by: Player) -> LooseRock:
	var r := LooseRock.new()
	r.weapon = weapon_id
	r.thrower = by
	r.velocity = moving
	r._home_in(at, in_room, by)
	return r

func _ready() -> void:
	add_to_group("loose_rocks")

## Makes a rock just dropped out of a throw still the throw as it falls: it
## strikes what it falls onto with `p`, for `team`, as `atk`'s blow, sparing
## what the throw struck already (`struck`), as many more times as the throw
## had left (`left`) — and its thrower too, if the throw had left their hand.
func arm(p: Payload, team: int, atk: Actor, struck: Array, left: int, at_thrower: bool) -> void:
	if p == null or left <= 0:
		return
	strikes = p
	_team = team
	_attacker = atk if atk != null and is_instance_valid(atk) else null
	_hit = struck.duplicate()
	_hits_left = left
	_at_thrower = at_thrower

func _process(delta: float) -> void:
	if not _placed:
		_placed = true
		_unstick()
	if not resting:
		_fly(delta)
	else:
		_down += delta
	_offer()

## A frame of the fall, or of sliding along the floor once it is down: only a
## rock from then on.
func _fly(delta: float) -> void:
	if _on_floor() and velocity.y >= 0.0:
		_spend_on_rock()
		_down += delta
		velocity.y = 0.0
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		if is_zero_approx(velocity.x):
			resting = true
			return
		_travel(delta)
	else:
		_fall_by(delta)

## One short step: across first, then down — and, still the throw, what it
## touches on the way is struck.
func _hop(step: Vector2) -> bool:
	_move(step)
	if strikes != null:
		_strike()
	return true

## Falling as the throw still: what it touches is struck, each once. Spent, it
## comes back off the last one struck, as a thrown rock does, and is a rock.
func _strike() -> void:
	var reached := Attacks.targets(_team)
	if _at_thrower and thrower != null and is_instance_valid(thrower) and not thrower.dead:
		# The Arena's list is not ours to add to.
		reached = reached + [thrower]
	for a in reached:
		if _hit.has(a) or not is_instance_valid(a):
			continue
		if global_position.distance_to(a.global_position) <= radius + a.hurt_radius:
			_hit.append(a)
			var dir := velocity.normalized() if velocity.length() > 1.0 else Vector2.DOWN
			Attacks.resolve_hit(strikes, a, global_position, dir, _attacker, room, _team)
			_hits_left -= 1
			if _hits_left <= 0:
				strikes = null
				velocity = Vector2(-velocity.x * 0.25, -180.0)
				return

## Across first, then down. What it meets across, it comes back off; what it
## meets coming down is the floor.
func _move(step: Vector2) -> void:
	if step.x != 0.0:
		var across := global_position + Vector2(step.x, 0.0)
		if _solid(across + Vector2(signf(step.x) * radius, 0.0)):
			_spend_on_rock()
			velocity.x = -velocity.x * BOUNCE
		else:
			global_position = across
	if step.y != 0.0:
		var down := global_position + Vector2(0.0, step.y)
		var edge := radius if step.y > 0.0 else -radius
		if not _solid(down + Vector2(0.0, edge)):
			global_position = down
		elif step.y > 0.0:
			_land()
		else:
			velocity.y = -velocity.y * BOUNCE

## Down onto the floor: flush with it, and either off it again, slower, or
## stopped coming down and only sliding now. Only a rock from here on.
func _land() -> void:
	_spend_on_rock()
	_settle_down()
	var hit := velocity.y
	if hit > REST_SPEED:
		velocity.y = -hit * BOUNCE
		velocity.x *= 0.7
	else:
		velocity.y = 0.0
	Cues.at(&"rock_down", global_position + Vector2(0.0, radius), {"weapon": weapon, "speed": hit})

## The throw it still was, if any, goes off here, where it met the rock — a
## wall, the ground — unless it was spent on what it struck on the way down.
## Only a rock after.
func _spend_on_rock() -> void:
	if strikes == null:
		return
	if _hits_left > 0:
		var dir := velocity.normalized() if velocity.length() > 1.0 else Vector2.DOWN
		Attacks.land(strikes, global_position, dir, _attacker, room, _team)
	strikes = null

## Picked up by the hands that threw it, if they are on it. Or gone, if the
## weapon is back in hand some other way.
func _offer() -> void:
	if thrower == null or not is_instance_valid(thrower) or thrower.dead:
		return
	if not thrower.weapons.has(weapon):
		return
	if thrower.holds(weapon):
		queue_free()
		return
	if _down < SETTLE:
		return
	var hands := thrower.vessel()
	if _hands_on(hands, REACH):
		thrower.take_back(weapon, hands)
		Cues.at(&"rock_back", global_position, {"weapon": weapon})
		picked_up.emit(self, hands)
		queue_free()

## What a room writes down for it when the player walks out leaving it there.
func record() -> Dictionary:
	return {"weapon": weapon, "pos": [global_position.x, global_position.y]}
