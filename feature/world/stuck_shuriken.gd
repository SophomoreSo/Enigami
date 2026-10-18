class_name StuckShuriken
extends FallingThing

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

## How far from its point to the middle of it: the tile it is drawn with is
## seven pixels of the picture across, two of the world's each.
const RADIUS := 7.0
## How close the hands have to come: touching it, give or take.
const REACH := 10.0
## How long one comes down with no room to stick in before it is given up:
## a screen with no ground has nothing for it to stop on.
const ADRIFT := 3.0
## How far, as a monster lets go of it, it is knocked up off the body.
const SHAKEN := 120.0

## Which weapon this is one of.
var weapon: String = "SHURIKEN"
## Whose it is: the only hands that take it back are this player's.
var thrower: Player = null
## The monster it is in, and where on it from the monster's middle; null when
## it is in a wall, or coming down.
var host: Actor = null
var _offset: Vector2 = Vector2.ZERO
## The way it was going when it struck, which is the way it points in what it
## struck.
var heading: Vector2 = Vector2.RIGHT
## Whether it is coming down rather than stuck.
var falling: bool = false
## How long it has been coming down with no room under it.
var _adrift: float = 0.0

func _init() -> void:
	radius = RADIUS

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
	s._home_in(at, in_room, by)
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
	_down += delta
	_offer()

## A frame of coming down. With no room to come down in, it is given up after
## a while.
func _fall(delta: float) -> void:
	if room == null:
		_adrift += delta
		if _adrift >= ADRIFT:
			queue_free()
			return
	_fall_by(delta)

## The first thing it meets, it sticks in; out past the room, it is gone.
func _hop(step: Vector2) -> bool:
	var next := global_position + step
	if _out_of_bounds(next):
		queue_free()
		return false
	if _solid(next):
		falling = false
		if velocity.length() > 0.01:
			heading = velocity.normalized()
		velocity = Vector2.ZERO
		_down = 0.0
		return false
	global_position = next
	return true

## Taken back by the hands that threw it, if they are on it and the stack has
## room for it.
func _offer() -> void:
	if _down < SETTLE:
		return
	if thrower == null or not is_instance_valid(thrower) or thrower.dead:
		return
	var hands := thrower.vessel()
	if not _hands_on(hands, REACH):
		return
	if not thrower.take_one_back(weapon):
		return
	Cues.at(&"shuriken_back", global_position, {"weapon": weapon})
	picked_up.emit(self, hands)
	queue_free()

## Whether it is where it can be taken back from: still, and in no monster.
func stuck() -> bool:
	return host == null and not falling
