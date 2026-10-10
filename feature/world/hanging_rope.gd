class_name HangingRope
extends Node2D

## A rope hung from the rock — a raid room's cable, a rope laid in a made map —
## and something a body takes hold of (`Player`): up held within reach of it
## takes it in the hands, left and right swing on it, up and down climb it, and
## a jump lets go of it.
##
## It stands where it hangs from, its anchor, and hangs `length` straight down
## from there. That line is all the rules see of it while nobody holds it: how
## it sways when somebody goes through it is its picture's (`Rope`, in
## graphics/), which reads where this one is held and follows. Held, it runs
## straight and taut from the anchor to the hands, and whoever holds it says
## where those are (`hold`), every frame they do.
##
## A room hangs its own (`Room.ropes`): where is the room's to say, and what
## kind of line each is, by the id of its row of `ropes` in the content
## database, is for the picture to draw it as.
##
## Nothing here draws.

## Which kind of line it is: its row of `ropes`, by id.
var kind: String = "cable"
## How far it hangs straight down from its anchor, in the world's units.
var length: float = 96.0
## The cell a rope laid in a made map starts in, the top of its run — what the
## map hangs it from. Off the map for one a room hung itself.
var cell: Vector2i = Vector2i(-1, -1)
## Who holds it, or null.
var holder: Node2D = null
## Where the hands are on it, in the world, and how far down it from the anchor.
## Kept by whoever holds it, and only meant while somebody does.
var hands: Vector2 = Vector2.ZERO
var grip: float = 0.0

## Hung from `at`, `long` straight down: a line of `of_kind`, and for one laid in
## a map, the cell it was laid from.
func setup(at: Vector2, long: float, of_kind: String = "cable", laid: Vector2i = Vector2i(-1, -1)) -> void:
	position = at
	length = maxf(long, 0.0)
	kind = of_kind
	cell = laid

## Where it hangs from, in the world.
func anchor() -> Vector2:
	return global_position

## Its end, in the world, as it hangs while nobody holds it.
func tip() -> Vector2:
	return anchor() + Vector2(0.0, length)

## Whether somebody holds it.
func held() -> bool:
	return holder != null and is_instance_valid(holder)

## How far down it a hand at `at` would take hold of it, from its anchor — or
## -1, out of its reach: further than `across` either side of the line, or more
## than `past` above its anchor or below its end. A hand anywhere between holds
## it where it is level with it, and one over the anchor or under the end
## holds it at that end.
func reach(at: Vector2, across: float, past: float) -> float:
	var a := anchor()
	if absf(at.x - a.x) > across:
		return -1.0
	var down := at.y - a.y
	if down < -past or down > length + past:
		return -1.0
	return clampf(down, 0.0, length)

## Taken in the hands of `by`, `along` down it from the anchor, the hands at
## `at` in the world.
func hold(by: Node2D, at: Vector2, along: float) -> void:
	holder = by
	hands = at
	grip = clampf(along, 0.0, length)

## Let go of: it hangs from its anchor again, however its picture swings it.
func let_go() -> void:
	holder = null
