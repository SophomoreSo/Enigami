class_name Rope
extends Node2D

## A line that moves: a rope, a cable, a wire — hung from something, swaying
## when somebody walks through it, and drawn on the world's pixel grid.
##
## It is aarthificial's dynamic line from Legacy devlog #21
## (https://www.youtube.com/watch?v=nlzvesTsSrI), on the CPU. The line is a
## tree of nodes, each knowing its parent, the angle and the distance it wants
## to keep from it, and whether it is fixed in place; the line as a whole
## carries what the simulation shares — how firmly a node keeps the angle it
## was made with, how fast its motion dies down, how much the world pulls on
## it, how much of a passing body's speed it takes. Every physics frame each
## free node falls, carries its speed, is pulled part of the way toward the
## spot its parent's heading and its own rest angle put it, and is then set
## at exactly its distance from its parent, the parent standing still — so
## a line hung from a point swings like the chain it is, and what hangs
## below a push swings after it while what is above stays put. A body
## moving through it — the player, a monster — hands it some of its speed.
## That is the video's velocity buffer done by asking the bodies directly:
## not a collision, but the good enough reaction it describes.
##
## The video calls its simulation spring-based, and the article it took it
## from cannot be read any more. A spring for the distance, tried first,
## cannot be made to sway: a chain of one-way springs is a chain of
## resonators, each driven by its parent at its own frequency, so every node
## swings harder than the one above it and the tail folds over itself, and
## the only damping that stops it stops the swing too. Keeping the distance
## outright and springing only the shape is how a strand of hair is kept on
## a GPU, node from parent, and it is steady at any stiffness.
##
## The picture is the video's too: the line is Bresenham's, pixel by pixel,
## each pixel a square on the grid the pixel camera draws the world at, so it
## is one buffer pixel wide however it lies. The video builds that mesh in a
## geometry shader and runs the simulation in a compute shader, for
## thousands of nodes; a room here hangs a handful of cables of a dozen nodes
## each, so both are plain GDScript — and Godot's 2D has no geometry shader
## to put the mesh in anyway.
##
## A node's rest angle is measured from the heading its parent was hung at,
## the direction the parent lies in from its own parent when nothing moves
## it, so a line keeps the shape it was made with: bend it and it straightens
## again, what hangs below a push is dragged after it by its length, and what
## is above, held from the anchor, stays put. Measuring from the parent's
## live direction instead was tried, and reads worse: a bend passed down the
## line that way keeps the tail moving long after the top has settled. The
## root's `angle` is its heading outright. A branch is a node whose parent is
## not the one before it; `attach` puts another node on the line to ride it,
## the way the video offsets sprites along one.
##
## Nothing here is a rule. It changes nothing and reads only where bodies are
## and how fast they move; a world without a picture has no cables in it and
## never misses them.

## The width of the line, and the grid it is drawn on: one pixel of the buffer
## the pixel camera draws the world into.
const S := PixelCamera.SCALE
## How far apart a hung cable's nodes are, in world pixels: six buffer pixels,
## close enough to bend where a body passes.
const SEGMENT := 12.0
## Bodies moving slower than this move nothing. Standing in a cable is not
## pushing it, and the video's buffer holds no speed for a body standing still.
const PUSH_MIN := 30.0
## How far past a body's own edge it still reaches the line: the line's width.
const PUSH_REACH := float(S)
## What `settle` runs, in physics frames at sixty a second: four seconds, long
## enough for the damping to take the drop out of a freshly hung line.
const SETTLE_STEPS := 240
## A body with no size of its own is taken to be about the player's.
const BODY_GUESS := Vector2(20.0, 30.0)

## --- what the whole line shares ---------------------------------------------
## How firmly the line keeps the angles it was made with, per second: a wire
## hung out from a wall droops under gravity at 1, and holds its line at 30.
## The distance to a parent is kept outright whatever this is, so a cable
## hung from a point is a chain at 0 and a rod at 60.
var stiffness: float = 3.0
## How fast a node's motion dies away, per second: at 0.8, a swing is down to
## a third in a second and a half.
var damping: float = 0.8
## How hard the world pulls every free node down, in pixels a second squared:
## half what a body feels, which reads as a cable's weight rather than a
## stone's, and swings a cable a few cells long once every couple of seconds.
var gravity: float = 900.0
## What part of a passing body's speed a node it covers takes, each physics frame.
var give: float = 0.35
## The most a node may move, in pixels a second: a dash through a cable bends
## it, and does not throw it across the room.
var max_speed: float = 900.0
## The line's colour, and the plug on each free end.
var color: Color = Style.ROPE
var end_color: Color = Style.ROPE_END

## The nodes, in the order they were added — a parent always before its
## children — each `{parent, angle, length, fixed, heading, pos, vel}`:
##
##   parent   the index it hangs from; -1 for the root
##   angle    where it wants to lie from its parent, in radians off the
##            parent's own heading; the root's is its heading outright
##   length   how far from its parent it wants to be
##   fixed    held where it was put
##   heading  the direction it lies in from its parent at rest, outright
##   pos vel  where it is and how it moves, in this node's own space
var nodes: Array = []
## What rides the line: `{node, index, offset}`.
var _riders: Array = []

## --- building ---------------------------------------------------------------

## The first node, held at `at`, heading `heading`: straight down for a cable
## hung from a ceiling, along for a wire slung out from a wall. Starts the
## line over.
func root(at: Vector2, heading: float) -> int:
	nodes.clear()
	nodes.append({"parent": -1, "angle": heading, "length": 0.0, "fixed": true,
		"heading": heading, "pos": at, "vel": Vector2.ZERO})
	return 0

## A node hung from `parent`, wanting to lie `angle` off its parent's heading
## and `length` from it, and put there to start. `fixed` holds it there for
## good — a cable slung between two points is a chain whose last node is
## fixed. Answers its index, to hang the next from.
func add_node(parent: int, angle: float, length: float, fixed: bool = false) -> int:
	if parent < 0 or parent >= nodes.size():
		push_error("Rope: no node %d to hang from" % parent)
		return -1
	var heading := float(nodes[parent]["heading"]) + angle
	var pos: Vector2 = nodes[parent]["pos"] + Vector2.from_angle(heading) * length
	nodes.append({"parent": parent, "angle": angle, "length": length, "fixed": fixed,
		"heading": heading, "pos": pos, "vel": Vector2.ZERO})
	return nodes.size() - 1

## A cable: hung from `at` straight down, `length` long, a node every `segment`.
func hang(at: Vector2, length: float, segment: float = SEGMENT) -> void:
	var last := root(at, PI * 0.5)
	for i in maxi(1, int(round(length / segment))):
		last = add_node(last, 0.0, segment)

## `rider` is carried to node `i`, `offset` from it, now and every frame after:
## a lamp on the end of its cable, a sign on its chain.
func attach(rider: Node2D, i: int, offset: Vector2 = Vector2.ZERO) -> void:
	_riders.append({"node": rider, "index": i, "offset": offset})
	_carry()

## Run until still without drawing a frame of it, so a line hung as a room is
## built is already hanging when the room is first seen.
func settle(steps: int = SETTLE_STEPS) -> void:
	for i in steps:
		step(1.0 / 60.0)

## --- asking -----------------------------------------------------------------

## Where node `i` is, in this node's space.
func point_of(i: int) -> Vector2:
	if i < 0 or i >= nodes.size():
		return Vector2.ZERO
	return nodes[i]["pos"]

## Speed given to node `i` outright, for whatever moves a line other than a
## body walking through it. A fixed node takes none.
func nudge(i: int, speed: Vector2) -> void:
	if i >= 0 and i < nodes.size() and not nodes[i]["fixed"]:
		nodes[i]["vel"] += speed

## The free ends: every node nothing hangs from, the root aside.
func tips() -> Array[int]:
	var hung := {}
	for n in nodes:
		hung[int(n["parent"])] = true
	var out: Array[int] = []
	for i in range(1, nodes.size()):
		if not hung.has(i):
			out.append(i)
	return out

## --- the simulation ---------------------------------------------------------

## One physics frame. Every free node falls, carries its speed, slows, takes
## speed from any body moving through it, is pulled part of the way toward
## where its parent's heading and its own rest angle put it, and is set at
## exactly its distance from its parent. Parents go before children, and a
## child reads its parent as it is now, so a bend runs down the line within
## the frame it is made. What a node ends up moving is its speed for the
## next frame, whatever it was asked to do.
func step(delta: float) -> void:
	if delta <= 0.0:
		return
	var movers := _movers()
	var damp := exp(-damping * delta)
	var keep := 1.0 - exp(-stiffness * delta)
	for i in range(1, nodes.size()):
		var n: Dictionary = nodes[i]
		if n["fixed"]:
			continue
		var parent: int = n["parent"]
		var at: Vector2 = n["pos"]
		var vel: Vector2 = (n["vel"] + Vector2(0.0, gravity) * delta) * damp
		for m in movers:
			if (m["rect"] as Rect2).has_point(at):
				vel = vel.lerp(m["vel"], give)
		var next := at + vel.limit_length(max_speed) * delta
		var hung: Vector2 = nodes[parent]["pos"]
		var rest := hung + Vector2.from_angle(_heading(parent) + float(n["angle"])) * float(n["length"])
		next = next.lerp(rest, keep)
		var d := next - hung
		next = rest if d.length_squared() < 0.0001 else hung + d.normalized() * float(n["length"])
		n["vel"] = (next - at) / delta
		n["pos"] = next
	_carry()

func _physics_process(delta: float) -> void:
	step(delta)
	queue_redraw()

## The direction node `i` was hung in from its parent, which its children
## measure their rest angles from. The root has no parent, and its heading is
## its own `angle`.
func _heading(i: int) -> float:
	return float(nodes[i]["heading"])

## The bodies moving through the world this frame — every actor going faster
## than PUSH_MIN — each as the rect it covers, in this node's space, with its
## speed. The video reads these off a buffer of every moving thing's speed at
## every pixel; for the handful of bodies a room holds, asking each is the
## same answer.
func _movers() -> Array:
	var out: Array = []
	if not is_inside_tree():
		return out
	for a in get_tree().get_nodes_in_group("actors"):
		if not (a is CharacterBody2D) or not is_instance_valid(a) or a.is_queued_for_deletion():
			continue
		var vel: Vector2 = (a as CharacterBody2D).velocity
		if vel.length() < PUSH_MIN:
			continue
		var size = a.get("body_size")
		if not (size is Vector2):
			size = BODY_GUESS
		var at := to_local((a as Node2D).global_position)
		out.append({"rect": Rect2(at - (size as Vector2) * 0.5, size).grow(PUSH_REACH), "vel": vel})
	return out

func _carry() -> void:
	for r in _riders:
		var rider: Node2D = r["node"]
		var i: int = r["index"]
		if rider == null or not is_instance_valid(rider) or i < 0 or i >= nodes.size():
			continue
		rider.global_position = to_global(nodes[i]["pos"] + r["offset"])

## --- the picture ------------------------------------------------------------

## The line, pixel by pixel: Bresenham's from each node to its parent on the
## buffer's grid, each pixel a square S wide, so the line is one buffer pixel
## wide whichever way it lies — the video's mesh of pixels, drawn by hand. A
## free end gets a plug three pixels square.
func _draw() -> void:
	for px in pixels():
		draw_rect(Rect2(_from_pixel(px), Vector2.ONE * S), color)
	for i in tips():
		draw_rect(Rect2(_from_pixel(_pixel(nodes[i]["pos"]) - Vector2i.ONE), Vector2.ONE * S * 3), end_color)

## Every pixel of the line as it lies now, in buffer pixels, each once.
func pixels() -> Array[Vector2i]:
	var seen := {}
	var out: Array[Vector2i] = []
	for i in range(1, nodes.size()):
		var n: Dictionary = nodes[i]
		for px in bresenham(_pixel(nodes[n["parent"]]["pos"]), _pixel(n["pos"])):
			if not seen.has(px):
				seen[px] = true
				out.append(px)
	return out

## Every pixel on the line from `a` to `b`, both included, each touching the
## one before at a side or a corner: Bresenham's algorithm, over integers.
static func bresenham(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var p := a
	while true:
		out.append(p)
		if p == b:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			p.x += sx
		if e2 <= dx:
			err += dx
			p.y += sy
	return out

## The buffer pixel a point of the line lands on. The buffer's grid is the
## world's, S apart from the origin, so this is the world position floored to
## it — for a line that is not scaled or turned, which none is.
func _pixel(pos: Vector2) -> Vector2i:
	return Vector2i((to_global(pos) / S).floor())

func _from_pixel(px: Vector2i) -> Vector2:
	return to_local(Vector2(px) * S)
