class_name LooseRock
extends Node2D

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

signal picked_up(rock: LooseRock, by: Actor)

const GRAVITY := 1500.0
const MAX_FALL := 900.0
## Half its height, for meeting the floor and the walls: the tile it is drawn
## with is eight pixels of the picture high, two of the world's each.
const RADIUS := 8.0
## How much of its speed it keeps, the other way, off what it hits; and how
## slowly it has to be coming down to stop rather than bounce.
const BOUNCE := 0.35
const REST_SPEED := 110.0
## How quickly it stops sliding once it is down.
const FRICTION := 900.0
## The longest step it takes between looks at the room, so a fast one cannot
## pass through a wall a cell thick.
const MAX_STEP := 6.0
## How close the hands have to come: touching it, give or take.
const REACH := 8.0
## How long it has to have been out of the air before it can be picked up. A
## rock thrown at a wall it was thrown from beside lands at the thrower's feet,
## and is not straight back in the hand for another throw.
const SETTLE := 0.3

## Which weapon this is.
var weapon: String = "ROCK"
## Whose it is: the only hands that pick it up are this player's.
var thrower: Player = null
var room = null
var velocity: Vector2 = Vector2.ZERO
## Whether it has come to a stop on the floor.
var resting: bool = false
## How long it has been lying out of the air.
var _down: float = 0.0
var _placed: bool = false

## Puts the rock `weapon` down at `at`, moving at `moving`, in `in_room` — or,
## with no room to lie in, wherever attacks are kept — for `by` to pick back
## up. What a bolt that was the rock becomes when it is done flying, and what a
## monster lets go of when the player steps out of it.
static func drop(weapon_id: String, at: Vector2, moving: Vector2, in_room, by: Player) -> LooseRock:
	var r := LooseRock.new()
	r.weapon = weapon_id
	r.thrower = by
	# The room it was thrown in; failing that, the one its thrower stands in. A
	# rock left lying anywhere but a room would go nowhere when the room goes.
	var where = in_room
	if (where == null or not is_instance_valid(where)) and by != null and is_instance_valid(by):
		where = by.room
	r.room = where if where != null and is_instance_valid(where) else null
	r.velocity = moving
	var host: Node = r.room if r.room != null else Attacks.container()
	r.position = (host as Node2D).to_local(at) if host is Node2D else at
	if host != null:
		host.add_child(r)
	return r

func _ready() -> void:
	add_to_group("loose_rocks")

func _process(delta: float) -> void:
	if not _placed:
		_placed = true
		_unstick()
	if not resting:
		_fly(delta)
	else:
		_down += delta
	_offer()

## A rock put down inside the room's rock — a record carried across a change to
## how rooms are built, or a throw that ended hard against a corner — is lifted
## out of it, and failing that put where the room puts a player who walks in.
func _unstick() -> void:
	if not _solid(global_position):
		return
	for up in range(1, Room.CELL * 3):
		if not _solid(global_position + Vector2(0.0, -up)):
			global_position.y -= up
			return
	if room != null and room.has_method("spawn_point"):
		global_position = room.spawn_point()

func _fly(delta: float) -> void:
	if _on_floor() and velocity.y >= 0.0:
		_down += delta
		velocity.y = 0.0
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		if is_zero_approx(velocity.x):
			resting = true
			return
	else:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	var travel := velocity * delta
	var hops := maxi(1, int(ceil(travel.length() / MAX_STEP)))
	for i in hops:
		_move(travel / float(hops))

## One short step: across first, then down. What it meets across, it comes back
## off; what it meets coming down is the floor.
func _move(step: Vector2) -> void:
	if step.x != 0.0:
		var across := global_position + Vector2(step.x, 0.0)
		if _solid(across + Vector2(signf(step.x) * RADIUS, 0.0)):
			velocity.x = -velocity.x * BOUNCE
		else:
			global_position = across
	if step.y != 0.0:
		var down := global_position + Vector2(0.0, step.y)
		var edge := RADIUS if step.y > 0.0 else -RADIUS
		if not _solid(down + Vector2(0.0, edge)):
			global_position = down
		elif step.y > 0.0:
			_land()
		else:
			velocity.y = -velocity.y * BOUNCE

## Down onto the floor: flush with it, and either off it again, slower, or
## stopped coming down and only sliding now.
func _land() -> void:
	for i in MAX_STEP + 1:
		if _solid(global_position + Vector2(0.0, RADIUS + 1.0)):
			break
		global_position.y += 1.0
	var hit := velocity.y
	if hit > REST_SPEED:
		velocity.y = -hit * BOUNCE
		velocity.x *= 0.7
	else:
		velocity.y = 0.0
	Cues.at(&"rock_down", global_position + Vector2(0.0, RADIUS), {"weapon": weapon, "speed": hit})

func _on_floor() -> bool:
	return _solid(global_position + Vector2(0.0, RADIUS + 1.0))

func _solid(at: Vector2) -> bool:
	if room != null and not is_instance_valid(room):
		room = null
	return room != null and room.has_method("is_solid_at") and room.is_solid_at(at)

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
	if global_position.distance_to(hands.global_position) <= RADIUS + hands.hurt_radius + REACH:
		thrower.take_back(weapon, hands)
		Cues.at(&"rock_back", global_position, {"weapon": weapon})
		picked_up.emit(self, hands)
		queue_free()

## What a room writes down for it when the player walks out leaving it there.
func record() -> Dictionary:
	return {"weapon": weapon, "pos": [global_position.x, global_position.y]}
