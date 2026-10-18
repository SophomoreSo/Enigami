class_name FallingThing
extends Node2D

## Something that falls to the floor and lies there until hands come for it:
## the rock out of hand (`LooseRock`), a shuriken out of its throw
## (`StuckShuriken`), the diamond (`Diamond`), a kit a death left (`LostKit`).
## Each had a fall of its own — its own gravity, its own short steps between
## looks at the room so a fast one could not pass through a floor a cell
## thick, its own way of being lifted out of rock it was put down in and of
## being put down in a room, its own reach for the hands — and the four had
## drifted: one fell through thin floors, another landed a pixel off. This is
## the fall they share. What each does as it meets the floor or a wall is its
## own (`_hop`), and so is whose hands take it. Nothing here draws.

const GRAVITY := 1500.0
const MAX_FALL := 900.0
## The longest step taken between looks at the room.
const MAX_STEP := 6.0
## How long it has to have been down before hands can take it: one put down at
## the feet is not straight back in them.
const SETTLE := 0.3

## Half its height, for meeting the floor and the walls. Each thing sets its
## own from its picture.
var radius: float = 8.0
var room = null
var velocity: Vector2 = Vector2.ZERO
## Whether it lies still on the floor.
var resting: bool = false
## How long it has been down, out of the air.
var _down: float = 0.0

## Whether the room's rock is at `at`. A room torn down under it is no room.
func _solid(at: Vector2) -> bool:
	if room != null and not is_instance_valid(room):
		room = null
	return room != null and room.has_method("is_solid_at") and room.is_solid_at(at)

## Whether `at` is out past the room altogether.
func _out_of_bounds(at: Vector2) -> bool:
	return room != null and is_instance_valid(room) and room.has_method("out_of_bounds") \
		and room.out_of_bounds(at)

func _on_floor() -> bool:
	return _solid(global_position + Vector2(0.0, radius + 1.0))

## Put down inside the rock — a record carried across a change to how rooms are
## built, a throw that ended hard against a corner, a carrier hard up under a
## ceiling — it is lifted out of it, up to three cells; failing that, put where
## the room puts a player who walks in.
func _unstick() -> void:
	if not _solid(global_position):
		return
	for up in range(1, Room.CELL * 3):
		if not _solid(global_position + Vector2(0.0, -up)):
			global_position.y -= up
			return
	if room != null and room.has_method("spawn_point"):
		global_position = room.spawn_point()

## Down onto the floor it has just met, flush with it: a pixel at a time.
func _settle_down() -> void:
	for i in int(MAX_STEP) + 2:
		if _solid(global_position + Vector2(0.0, radius + 1.0)):
			break
		global_position.y += 1.0

## Puts it in the world at `at`: in `in_room`, or failing that in the room `by`
## stands in, and with no room at all wherever attacks are kept — one left
## lying anywhere but a room would go nowhere when the room goes, or outlast
## it.
func _home_in(at: Vector2, in_room, by: Node) -> void:
	var where = in_room
	if (where == null or not is_instance_valid(where)) and by != null and is_instance_valid(by):
		where = by.get("room")
	room = where if where != null and is_instance_valid(where) else null
	var host: Node = room if room != null else Attacks.container()
	position = (host as Node2D).to_local(at) if host is Node2D else at
	if host != null:
		host.add_child(self)

## Whether `hands` are on it: within `reach` of touching it.
func _hands_on(hands: Node2D, reach: float) -> bool:
	if hands == null or not is_instance_valid(hands):
		return false
	var theirs := float(hands.get("hurt_radius")) if hands.get("hurt_radius") != null else 0.0
	return global_position.distance_to(hands.global_position) <= radius + theirs + reach

## A frame of falling: gravity on `velocity`, then the frame's travel in hops
## no longer than MAX_STEP, each put to `_hop`, which says whether to go on.
func _fall_by(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	_travel(delta)

## The frame's travel by `velocity`, in hops, with no gravity on it: for one
## sliding along the floor.
func _travel(delta: float) -> void:
	var travel := velocity * delta
	var hops := maxi(1, int(ceil(travel.length() / MAX_STEP)))
	for i in hops:
		if not _hop(travel / float(hops)):
			return

## One short step of the fall. What it meets is the thing's own business:
## bounce off it, stick in it, lie down on it. Whether to go on hopping.
func _hop(step: Vector2) -> bool:
	global_position += step
	return true
