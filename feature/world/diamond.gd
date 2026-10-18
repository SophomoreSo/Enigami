class_name Diamond
extends FallingThing

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

## Half its height, for meeting the floor.
const RADIUS := 8.0
## How close the hands have to come: touching it, give or take.
const REACH := 8.0
## How far over the top of whoever carries it it rides: clear of the head,
## which is drawn taller than the body that bumps into things. Any nearer and
## the stone sits on the player's helmet like a hat.
const OVERHEAD := 24.0

## Whose hands can take it: the player's body, or whichever monster they are in.
var player: Player = null
## Who is carrying it, or null while it lies somewhere.
var carrier: Actor = null
## Where the one carrying it last stood, for letting go of it there should
## they be gone by the time it is noticed.
var _held_at: Vector2 = Vector2.ZERO

func _init() -> void:
	radius = RADIUS

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
	if _hands_on(hands, REACH):
		take(hands)

## Straight down, onto the floor under it, and still there.
func _fall(delta: float) -> void:
	if _on_floor() and velocity.y >= 0.0:
		velocity.y = 0.0
		_down += delta
		return
	_down = 0.0
	_fall_by(delta)

## Down onto the floor it meets, flush with it.
func _hop(step: Vector2) -> bool:
	var next := global_position + step
	if _solid(next + Vector2(0.0, radius)):
		_settle_down()
		velocity.y = 0.0
		return false
	global_position = next
	return true
