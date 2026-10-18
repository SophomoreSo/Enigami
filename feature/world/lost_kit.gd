class_name LostKit
extends FallingThing

## Everything a death left on the floor, lying on the spot it fell.
##
## One node and one pickup: the weapon, the graph that was built onto it, the
## components in the bag and the scrap all come back in a single touch — there
## is nothing to sort through and nothing to leave behind by accident.
## What is in it is `record`, which is the drop `GameState` has been keeping
## since the run that made it, written into this room's record when the map was
## built. `graphics/views/lost_kit_view.gd` draws it.

signal collected(kit: LostKit)

## Wider than a loose part's reach. A drop is the thing the whole run was for,
## so brushing past it counts; it does not have to be stood on exactly.
const PICKUP_RANGE := 30.0
## Half its height: how far under its middle the floor it lies on is.
const RADIUS := 10.0

var record: Dictionary = {}

func setup(rec: Dictionary, at: Vector2) -> void:
	record = rec
	position = at
	radius = RADIUS

func _ready() -> void:
	add_to_group("lost_kits")

func _process(delta: float) -> void:
	# It settles onto the floor and then stays put. Loot leaps out of whatever
	# dropped it and is drawn to whoever walks past; this is a landmark, and a
	# landmark that slid around would be a worse one. With no room under it,
	# it stays where it was put.
	if room != null and not resting:
		if _on_floor() and velocity.y >= 0.0:
			velocity = Vector2.ZERO
			resting = true
		else:
			_fall_by(delta)

	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p := players[0] as Node2D
	if p != null and global_position.distance_to(p.global_position) < PICKUP_RANGE:
		collected.emit(self)
		Cues.at(&"kit_back", global_position, {"size": size()})
		queue_free()

## Down onto the floor it meets, flush with it, and still.
func _hop(step: Vector2) -> bool:
	var next := global_position + step
	if _solid(next + Vector2(0.0, radius)):
		_settle_down()
		velocity = Vector2.ZERO
		resting = true
		return false
	global_position = next
	return true

## What is in it, as one number: a weapon counts for one, and so does every
## part built onto a graph that fell and every component in the bag. Scrap is
## not counted — it is the one thing in here that is only worth what it says.
## The profile counts it, since the profile is what wrote it down.
func size() -> int:
	return GameState.kit_size(record)
