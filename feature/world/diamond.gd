class_name Diamond
extends Node2D

## The Jean Grey test's prize: one stone, lying where it was left until hands the
## player is in walk onto it — their own body's, or a monster's they are in
## (`Player.vessel`). Whoever holds it carries it over their head. When the
## hands leave that body — hopping on to the next, stepping out, the time
## running out, the body dying — it is let go of where that body stands, and
## falls to the floor under it. A monster with its own mind never picks it up:
## it is the player's to take.
##
## It is the rock's rule (`LooseRock`) for something that is not a weapon, so a
## theft carried through three bodies is passed on the way the rock is.
## `graphics/views/diamond_view.gd` draws it.

signal picked_up(by: Actor)
signal let_go(at: Vector2)

const GRAVITY := 1500.0
const MAX_FALL := 900.0
## Half its height, for meeting the floor.
const RADIUS := 8.0
## The longest step it falls between looks at the room, so it cannot drop
## through a floor a cell thick.
const MAX_STEP := 6.0
## How close the hands have to come: touching it, give or take.
const REACH := 8.0
## How long it has to have lain still before it can be taken. One let go of is
## not straight back in the hands that let go of it.
const SETTLE := 0.3
## How far over the top of whoever carries it it rides: clear of the head,
## which is drawn taller than the body that bumps into things. Any nearer and
## the stone sits on the player's helmet like a hat.
const OVERHEAD := 24.0

## Whose hands can take it: the player's body, or whichever monster they are in.
var player: Player = null
var room = null
## Who is carrying it, or null while it lies somewhere.
var carrier: Actor = null
var velocity: Vector2 = Vector2.ZERO
## How long it has lain still.
var _down: float = 0.0
## Where the one carrying it last stood, for letting go of it there should
## they be gone by the time it is noticed.
var _held_at: Vector2 = Vector2.ZERO

## Puts it down at `at`, nobody's, ready to be taken.
func place(at: Vector2) -> void:
	carrier = null
	velocity = Vector2.ZERO
	global_position = at
	_down = SETTLE

func _process(delta: float) -> void:
	if carrier != null:
		_carry()
	else:
		_fall(delta)
		_offer()

## Whether it is in the player's own hands: their body's, not a monster's.
func carried_by_player() -> bool:
	return carrier != null and carrier == player

## Rides over the head of the hands holding it, for as long as they are the
## hands the player is in.
func _carry() -> void:
	var holding := is_instance_valid(carrier) and not (carrier as Actor).dead \
		and player != null and is_instance_valid(player) and not player.dead \
		and player.vessel() == carrier
	if not holding:
		_drop()
		return
	_held_at = carrier.global_position
	global_position = _held_at + Vector2(0.0, -(carrier.body_size.y * 0.5 + OVERHEAD))

## Out of the hands: from where they stood, to fall from there.
func _drop() -> void:
	carrier = null
	velocity = Vector2.ZERO
	_down = 0.0
	global_position = _held_at
	_unstick()
	let_go.emit(global_position)
	Cues.at(&"diamond_down", global_position, {})

## Taken by `hands`.
func take(hands: Actor) -> void:
	carrier = hands
	_held_at = hands.global_position
	picked_up.emit(hands)
	Cues.at(&"diamond_taken", global_position, {})

func _offer() -> void:
	if _down < SETTLE or player == null or not is_instance_valid(player) or player.dead:
		return
	var hands := player.vessel()
	if global_position.distance_to(hands.global_position) <= RADIUS + hands.hurt_radius + REACH:
		take(hands)

func _fall(delta: float) -> void:
	if _solid(global_position + Vector2(0.0, RADIUS + 1.0)) and velocity.y >= 0.0:
		velocity.y = 0.0
		_down += delta
		return
	_down = 0.0
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	var step := velocity.y * delta
	var hops := maxi(1, int(ceil(absf(step) / MAX_STEP)))
	for i in hops:
		var next := global_position + Vector2(0.0, step / float(hops))
		if _solid(next + Vector2(0.0, RADIUS)):
			# Down onto the floor, flush with it.
			for k in int(MAX_STEP) + 2:
				if _solid(global_position + Vector2(0.0, RADIUS + 1.0)):
					break
				global_position.y += 1.0
			velocity.y = 0.0
			return
		global_position = next

## Let go of inside the rock — a carrier hard up under a ceiling — it is lifted
## out of it.
func _unstick() -> void:
	for up in range(0, Room.CELL * 3):
		if not _solid(global_position + Vector2(0.0, -up)):
			global_position.y -= up
			return

func _solid(at: Vector2) -> bool:
	if room != null and not is_instance_valid(room):
		room = null
	return room != null and room.has_method("is_solid_at") and room.is_solid_at(at)
