class_name LostKit
extends Node2D

## Everything a death left on the floor, lying on the spot it fell.
##
## One node and one pickup: the weapon, the skills that were slotted into it,
## the components in the bag and the scrap all come back in a single touch —
## there is nothing to sort through and nothing to leave behind by accident.
## What is in it is `record`, which is the drop `GameState` has been keeping
## since the run that made it, written into this room's record when the map was
## built. `graphics/views/lost_kit_view.gd` draws it.

signal collected(kit: LostKit)

## Wider than a loose part's reach. A drop is the thing the whole run was for,
## so brushing past it counts; it does not have to be stood on exactly.
const PICKUP_RANGE := 30.0
const GRAVITY := 1100.0

var record: Dictionary = {}
var room = null
var velocity: Vector2 = Vector2.ZERO

func setup(rec: Dictionary, at: Vector2) -> void:
	record = rec
	position = at

func _ready() -> void:
	add_to_group("lost_kits")

func _process(delta: float) -> void:
	# It settles onto the floor and then stays put. Loot leaps out of whatever
	# dropped it and is drawn to whoever walks past; this is a landmark, and a
	# landmark that slid around would be a worse one.
	if room != null and room.has_method("is_solid_at"):
		var below := global_position + Vector2(0, 10) + velocity * delta
		if room.is_solid_at(below):
			velocity = Vector2.ZERO
		else:
			velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)
	position += velocity * delta

	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p := players[0] as Node2D
	if p != null and global_position.distance_to(p.global_position) < PICKUP_RANGE:
		collected.emit(self)
		Cues.at(&"kit_back", global_position, {"size": size()})
		queue_free()

## What is in it, as one number: a weapon and a skill each count for one, and so
## does every component in the bag. Scrap is not counted — it is the one thing
## in here that is only worth what it says.
func size() -> int:
	var n: int = (record.get("boards", []) as Array).size() \
		+ (record.get("weapons", []) as Array).size()
	for id in record.get("bag", {}):
		n += int((record["bag"] as Dictionary)[id])
	return n
