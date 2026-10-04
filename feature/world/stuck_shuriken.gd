class_name StuckShuriken
extends Node2D

## A shuriken where it struck (`Weapons.is_stacked`): in a wall at the point it
## met it, pointing the way it was going, or riding in a monster at the place
## it went in. Out of the end of its throw, or out of a monster that has died,
## it drops, and sticks in whatever it meets first.
##
## Standing still in a wall or a floor, the hands that threw it take it back by
## walking over it — the player's own, or a monster's they are in
## (`Player.possess`) — and it is one more in the stack (`Player.stock`). Not
## while the stack is already whole: then it stays where it is. One in a
## monster is out of reach until the monster lets go of it, by dying.
##
## It belongs to the room it struck in and goes with it. A room walked out of
## keeps no record of it (`Room.save_state`), so one left behind is gone.
## `graphics/views/stuck_shuriken_view.gd` draws it.

signal picked_up(shuriken: StuckShuriken, by: Actor)

const GRAVITY := 1500.0
const MAX_FALL := 900.0
## The longest step it takes coming down between looks at the room, so a fast
## one cannot pass through a floor a cell thick.
const MAX_STEP := 6.0
## How far from its point to the middle of it: the tile it is drawn with is
## seven pixels of the picture across, two of the world's each.
const RADIUS := 7.0
## How close the hands have to come: touching it, give or take.
const REACH := 10.0
## How long it has to have been still before it can be taken back. One thrown
## into a wall from beside it is not straight back in the stack for the next
## throw.
const SETTLE := 0.3
## How long one comes down with no room to stick in before it is given up:
## a screen with no ground has nothing for it to stop on.
const ADRIFT := 3.0
## How far, as a monster lets go of it, it is knocked up off the body.
const SHAKEN := 120.0

## Which weapon this is one of.
var weapon: String = "SHURIKEN"
## Whose it is: the only hands that take it back are this player's.
var thrower: Player = null
var room = null
## The monster it is in, and where on it from the monster's middle; null when
## it is in a wall, or coming down.
var host: Actor = null
var _offset: Vector2 = Vector2.ZERO
## The way it was going when it struck, which is the way it points in what it
## struck.
var heading: Vector2 = Vector2.RIGHT
## Whether it is coming down rather than stuck, and how fast.
var falling: bool = false
var velocity: Vector2 = Vector2.ZERO
## How long it has stood still, and how long it has been coming down.
var _still: float = 0.0
var _adrift: float = 0.0

## A shuriken of `weapon_id` stuck at `at`, going `moving` as it struck, in
## `in_room` — or in `into`, the monster it struck, at that place on it — for
## `by` to take back.
static func lodge(weapon_id: String, at: Vector2, moving: Vector2, in_room, by: Player,
		into: Actor = null) -> StuckShuriken:
	var s := _make(weapon_id, at, in_room, by)
	if moving.length() > 0.01:
		s.heading = moving.normalized()
	if into != null and is_instance_valid(into) and not into.dead:
		s.host = into
		s._offset = at - into.global_position
	return s

## A shuriken of `weapon_id` coming down from `at`, going `moving`, until it
## sticks in whatever it meets: one out of throw with nothing struck.
static func drop(weapon_id: String, at: Vector2, moving: Vector2, in_room, by: Player) -> StuckShuriken:
	var s := _make(weapon_id, at, in_room, by)
	s.falling = true
	s.velocity = moving
	if moving.length() > 0.01:
		s.heading = moving.normalized()
	return s

static func _make(weapon_id: String, at: Vector2, in_room, by: Player) -> StuckShuriken:
	var s := StuckShuriken.new()
	s.weapon = weapon_id
	s.thrower = by
	# The room it struck in; failing that, the one its thrower stands in. One
	# left anywhere but a room would outlast the room it is in.
	var where = in_room
	if (where == null or not is_instance_valid(where)) and by != null and is_instance_valid(by):
		where = by.room
	s.room = where if where != null and is_instance_valid(where) else null
	var home: Node = s.room if s.room != null else Attacks.container()
	s.position = (home as Node2D).to_local(at) if home is Node2D else at
	if home != null:
		home.add_child(s)
	return s

func _ready() -> void:
	add_to_group("stuck_shurikens")

func _process(delta: float) -> void:
	if room != null and not is_instance_valid(room):
		room = null
	if host != null:
		if is_instance_valid(host) and not host.dead:
			global_position = host.global_position + _offset
			return
		# The monster is gone, and lets go of it: knocked up off the body, and
		# down onto whatever is under it.
		host = null
		falling = true
		velocity = Vector2(0.0, -SHAKEN)
		heading = Vector2.DOWN
	if falling:
		_fall(delta)
		return
	_still += delta
	_offer()

## A frame of coming down, a short step at a time. The first thing it meets, it
## sticks in.
func _fall(delta: float) -> void:
	if room == null:
		_adrift += delta
		if _adrift >= ADRIFT:
			queue_free()
			return
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	var travel := velocity * delta
	var hops := maxi(1, int(ceil(travel.length() / MAX_STEP)))
	for i in hops:
		var next := global_position + travel / float(hops)
		if room != null and room.has_method("out_of_bounds") and room.out_of_bounds(next):
			queue_free()
			return
		if _solid(next):
			falling = false
			if velocity.length() > 0.01:
				heading = velocity.normalized()
			velocity = Vector2.ZERO
			_still = 0.0
			return
		global_position = next

func _solid(at: Vector2) -> bool:
	return room != null and room.has_method("is_solid_at") and room.is_solid_at(at)

## Taken back by the hands that threw it, if they are on it and the stack has
## room for it.
func _offer() -> void:
	if _still < SETTLE:
		return
	if thrower == null or not is_instance_valid(thrower) or thrower.dead:
		return
	var hands := thrower.vessel()
	if global_position.distance_to(hands.global_position) > RADIUS + hands.hurt_radius + REACH:
		return
	if not thrower.take_one_back(weapon):
		return
	Cues.at(&"shuriken_back", global_position, {"weapon": weapon})
	picked_up.emit(self, hands)
	queue_free()

## Whether it is where it can be taken back from: still, and in no monster.
func stuck() -> bool:
	return host == null and not falling
