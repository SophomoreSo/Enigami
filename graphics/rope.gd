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
## at exactly its distance from its parent — and what it was pulled by, its
## parent is pulled by the other way, a frame later. So a line hung from a
## point swings like the chain it is: what hangs below a push swings after
## it, and what is above is drawn after it too, all the way up to the anchor.
## A body moving through it — the player, a monster — hands it some of its
## speed, and so does an attack that goes through it: a bolt, a blast's ring,
## and what a lunge, a beam or a slash cut. That is the video's velocity
## buffer done by asking the bodies directly: not a collision, but the good
## enough reaction it describes.
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
## Kept that way and no further, a node weighs nothing to the one above it.
## Its parent never feels it, so nothing done to the end of a cable reached
## the top: a body through the bottom of one bent what it touched and left
## the rest standing like a rod, up to the anchor. And the pull toward the
## rest angle, felt by the child alone, was the chain of one-way resonators
## over again: at a good many of the numbers a line can be given, it never
## came to rest. The paper that keeps hair this way says as much — following
## the leader weighs each node as nothing beside its parent — and its answer
## is to hand the child's correction back to the parent as speed (Müller,
## Kim and Chentanez, "Fast Simulation of Inextensible Hair and Fur", 2012).
## That is `pull` here: what set a node at its length, and what drew it
## toward its rest angle, go to its parent turned round, to be taken up in
## the next frame. Two things are this line's own. A line pulls and cannot
## push, so a node pushed back out to its length hands nothing on: a body
## jumping up under a cable shoves the end of it, not the anchor. And the
## shape's pull is handed on along with the length's: left to the child
## alone it is a spring with one end, and that is what kept a line from
## resting. The weight of everything hanging from a node reaches it the same
## way, which is what makes the top of a cable harder to move than its end.
##
## The picture is the video's too: the line is Bresenham's, pixel by pixel,
## each pixel a square on the grid the pixel camera draws the world at, so it
## is one buffer pixel wide however it lies. The video builds that mesh in a
## geometry shader and runs the simulation in a compute shader, for
## thousands of nodes; a room here hangs a handful of cables of a few nodes
## each, so both are plain GDScript — and Godot's 2D has no geometry shader
## to put the mesh in anyway.
##
## A node's rest angle is measured from the heading its parent was hung at,
## the direction the parent lies in from its own parent when nothing moves
## it, so a line keeps the shape it was made with: bend it and it straightens
## again, and what hangs below a push is dragged after it by its length.
## Measuring from the parent's live direction instead was tried, and reads
## worse: a bend passed down the line that way keeps the tail moving long
## after the top has settled. The root's `angle` is its heading outright. A
## branch is a node whose parent is not the one before it; `attach` puts
## another node on the line to ride it, the way the video offsets sprites
## along one — a lantern on the end of its cord — and a rider with a body of
## its own is something to walk into: a body through the lantern swings the
## cord it hangs on, as one through a node of the line does.
##
## A kind of line — a cable, a chain — is a row of `ropes` in the content
## database, and its numbers are the ones below; `of` makes a line of a kind,
## and `hangings` says what a room hangs of each ("A rope" in
## data/db/README.md). What keeps a line steady whatever the numbers say
## stays here, as constants, and so does its look, in `Style`.
##
## Nothing here is a rule. It changes nothing and reads only where bodies are
## and how fast they move; a world without a picture has no cables in it and
## never misses them.

## The width of the line, and the grid it is drawn on: one pixel of the buffer
## the pixel camera draws the world into.
const S := PixelCamera.SCALE
## Bodies moving slower than this move nothing. Standing in a cable is not
## pushing it, and the video's buffer holds no speed for a body standing still.
const PUSH_MIN := 30.0
## The most of its distance from its parent a node's own speed may move it in
## one step. Past half, a node could pass its parent within a step, and the
## line would fold; at this, two neighbours cannot close on each other in a
## step either.
const MOST_A_STEP := 0.4
## How far past a body's own edge it still reaches the line: the line's width.
const PUSH_REACH := float(S)
## What `settle` runs, in physics frames at sixty a second: four seconds, long
## enough for the damping to take the drop out of a freshly hung line.
const SETTLE_STEPS := 240
## A body with no size of its own is taken to be about the player's.
const BODY_GUESS := Vector2(20.0, 30.0)
## How long an attack that is over the moment it is made — a lunge, a beam, a
## slash — goes on handing its speed to what it went through: three frames at
## sixty, which is about what a dash through a line gets. Its picture hangs in
## the air longer than that, and is not what pushes.
const CUT_FOR := 0.05
## How wide the ring a blast pushes out is, as it opens: the velocity buffer's.
const BLAST_RING := 16.0

## --- what the whole line shares ---------------------------------------------
## The numbers a kind of line is, as its row of `ropes` has them; made by
## hand, a line has the ones given here.
## Which kind of line this is: the id of its row.
var kind: String = "cable"
## How far apart a hung line's nodes are, in world pixels: at 12, six buffer
## pixels, close enough to bend where a body passes.
var segment: float = 12.0
## How firmly the line keeps the angles it was made with, per second: a wire
## hung out from a wall droops under gravity at 1, and holds its line at 30.
## The distance to a parent is kept outright whatever this is, so a cable
## hung from a point is a chain at 0 and a rod at 60. The pull is between a
## node and its parent, each feeling the other's half, so what it holds
## hardest is the line's shape: a stiff cable stays straight and swings from
## its anchor all of a piece, and the stiffer it is the less far.
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
## The most speed a body hands over, in pixels a second, however fast it is
## going: at 220, a walk's worth. A dash or a fall through a cable at the
## body's own speed threw the nodes it touched further in a frame than they
## hang apart, and the line folded over itself and shook.
var push_most: float = 220.0
## The line's colour, and the plug on each free end: the kind's look.
var color: Color = Style.rope_look("cable")["line"]
var end_color: Color = Style.rope_look("cable")["end"]

## The nodes, in the order they were added — a parent always before its
## children — each `{parent, angle, length, fixed, heading, pos, vel, pull}`:
##
##   parent   the index it hangs from; -1 for the root
##   angle    where it wants to lie from its parent, in radians off the
##            parent's own heading; the root's is its heading outright
##   length   how far from its parent it wants to be
##   fixed    held where it was put
##   heading  the direction it lies in from its parent at rest, outright
##   pos vel  where it is and how it moves, in this node's own space
##   pull     the speed its children handed it in the last step — the other
##            half of what held them to it — for it to take up in the next
var nodes: Array = []
## What rides the line: `{node, index, offset, body}`.
var _riders: Array = []
## Where each bolt in the air was a step ago, by its instance: a bolt is taken
## from there to where it is now, so a fast one is not past the line between
## two steps.
var _bolts: Dictionary = {}

## --- building ---------------------------------------------------------------

## The first node, held at `at`, heading `heading`: straight down for a cable
## hung from a ceiling, along for a wire slung out from a wall. Starts the
## line over.
func root(at: Vector2, heading: float) -> int:
	nodes.clear()
	nodes.append({"parent": -1, "angle": heading, "length": 0.0, "fixed": true,
		"heading": heading, "pos": at, "vel": Vector2.ZERO, "pull": Vector2.ZERO})
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
		"heading": heading, "pos": pos, "vel": Vector2.ZERO, "pull": Vector2.ZERO})
	return nodes.size() - 1

## A cable: hung from `at` straight down, `length` long, a node every
## `spacing` — the kind's own `segment` unless told otherwise.
func hang(at: Vector2, length: float, spacing: float = 0.0) -> void:
	if spacing <= 0.0:
		spacing = segment
	var last := root(at, PI * 0.5)
	for i in maxi(1, int(round(length / spacing))):
		last = add_node(last, 0.0, spacing)

## `rider` is carried by node `i`, now and every frame after: a lamp on the
## end of its cable, a sign on its chain. It is put on the pixel its node is
## drawn on — that pixel's corner, and `offset` from it — so it stands on the
## buffer's grid as the line does, and is never a pixel off the end of it.
##
## `body` is the room the rider takes up, in its own space. With one, a body
## moving through the rider moves its node, as one moving through the node
## does: a lamp is walked into where the lamp is, and not only where its cable
## ends. It is shouldered aside by a body that meets it along the way it
## hangs (`glanced`), and handed less the further it has swung from there,
## so a body that stays in it leans it aside and holds it, and never carries
## it up over what it hangs from. And a free end with a rider on it has no
## plug: the rider is its end.
func attach(rider: Node2D, i: int, offset: Vector2 = Vector2.ZERO, body: Rect2 = Rect2()) -> void:
	_riders.append({"node": rider, "index": i, "offset": offset, "body": body})
	_carry()

## Run until still without drawing a frame of it, so a line hung as a room is
## built is already hanging when the room is first seen.
func settle(steps: int = SETTLE_STEPS) -> void:
	for i in steps:
		step(1.0 / 60.0)

## --- the table --------------------------------------------------------------

## Every kind of line in the table, by id.
static func kinds() -> PackedStringArray:
	var out := PackedStringArray()
	for r in Db.rows("SELECT id FROM ropes ORDER BY id"):
		out.append(String(r["id"]))
	return out

## A kind as the table has it — its row of `ropes` — or {} for no such kind.
static func source(id: String) -> Dictionary:
	var found := Db.records("ropes", "id = ?", [id])
	return found[0] if not found.is_empty() else {}

## A line of kind `id`: its row's numbers, and its look. A kind that is not
## in the table is said loudly, and the line is a cable.
static func of(id: String) -> Rope:
	var rope := Rope.new()
	var row := source(id)
	if row.is_empty():
		push_error("Rope: no kind of line called '%s' in %s" % [id, Db.PATH])
		return rope
	rope.kind = id
	rope.segment = float(row["segment"])
	rope.stiffness = float(row["stiffness"])
	rope.damping = float(row["damping"])
	rope.gravity = float(row["gravity"])
	rope.give = float(row["give"])
	rope.push_most = float(row["push_most"])
	var look := Style.rope_look(id)
	rope.color = look["line"]
	rope.end_color = look["end"]
	return rope

## What a room hangs: the rows of `hangings`, each the kind of line (`rope`),
## how many (`fewest` to `most`) and how long in cells (`shortest` to
## `longest`), in the order they were written.
static func hangings() -> Array:
	return Db.records("hangings", "", [], "rowid")

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
## speed from any body moving through it, moves — never more than
## MOST_A_STEP of its segment of its own accord, and then by whatever its
## children handed it in the last frame — is pulled part of the way toward
## where its parent's heading and its own rest angle put it, and is set at
## exactly its distance from its parent. What those two moved it by, its
## parent is handed turned round, for the next frame: the shape's pull
## always, and the length's only when the line was taut, since a line cannot
## push. Parents go before children, and a child reads its parent as it is
## now, so a bend runs down the line within the frame it is made, and up it
## a node a frame. What a node ends up moving is its speed for the next
## frame, whatever it was asked to do.
func step(delta: float) -> void:
	if delta <= 0.0:
		return
	var movers := _movers()
	var bodies := _bodies()
	var damp := exp(-damping * delta)
	var keep := 1.0 - exp(-stiffness * delta)
	for i in range(1, nodes.size()):
		var n: Dictionary = nodes[i]
		if n["fixed"]:
			continue
		var parent: int = n["parent"]
		var at: Vector2 = n["pos"]
		var length: float = n["length"]
		var vel: Vector2 = (n["vel"] + Vector2(0.0, gravity) * delta) * damp
		var hung: Vector2 = nodes[parent]["pos"]
		# The way it lies from its parent when nothing moves it.
		var hangs := Vector2.from_angle(_heading(parent) + float(n["angle"]))
		# What rides this node, as the room it takes up where it has been
		# carried to: from the corner of the pixel the node is drawn on.
		var ridden_here: Rect2 = bodies.get(i, Rect2())
		if ridden_here.has_area():
			ridden_here.position += _from_pixel(_pixel(at))
		# Each thing that moves hands its speed over the once, however many
		# pieces it comes in: a lunge is a row of them down its path.
		var handed := {}
		for m in movers:
			if handed.has(m["of"]):
				continue
			var reach := _reach(m, at, ridden_here)
			if reach.is_empty():
				continue
			handed[m["of"]] = true
			if ridden_here.has_area():
				# The further a rider has swung from the way it hangs, the more
				# of it is clear of the body, and the less the body hands it:
				# by the cosine of how far, and nothing past a right angle.
				var clear := clampf((at - hung).normalized().dot(hangs), 0.0, 1.0)
				vel = vel.lerp(glanced(reach[0], hangs, ridden_here.get_center() - (reach[1] as Vector2))
					.limit_length(push_most), give * clear)
			else:
				vel = vel.lerp(reach[0], give)
		# Where it was asked to go: by its own speed, held to MOST_A_STEP, and by
		# what hangs from it. That second part is held to nothing: nearly all of
		# it is the weight below, which lies along the line and is taken straight
		# back out by the length.
		var asked := at + (vel * delta).limit_length(MOST_A_STEP * length) + (n["pull"] as Vector2) * delta
		n["pull"] = Vector2.ZERO
		var rest := hung + hangs * length
		var next := asked.lerp(rest, keep)
		var d := next - hung
		var far := d.length()
		var held := rest if far < 0.01 else hung + d * (length / far)
		n["vel"] = (held - at) / delta
		n["pos"] = held
		if not nodes[parent]["fixed"]:
			var back := asked - next
			if far > length:
				back += next - held
			nodes[parent]["pull"] += back / delta
	_carry()

## What mover `m` hands a node at `at`, with what rides it taking up `rides`
## (no area: nothing does): its speed and where its middle is, as [speed,
## middle] — or nothing, when it reaches neither the node nor what rides it. A
## blast is a ring opening from its centre, and hands its speed outward to
## whatever its edge is on; anything else is the rect it covers.
func _reach(m: Dictionary, at: Vector2, rides: Rect2) -> Array:
	if m.has("ring"):
		var centre: Vector2 = m["ring"]
		var struck := rides.get_center() if rides.has_area() else at
		var slack := maxf(rides.size.x, rides.size.y) * 0.5 if rides.has_area() else 0.0
		var far := struck.distance_to(centre)
		if far < 0.01 or absf(far - float(m["r"])) > float(m["wide"]) * 0.5 + slack:
			return []
		return [(struck - centre) / far * float(m["speed"]), centre]
	var through: Rect2 = m["rect"]
	if through.has_point(at) or (rides.has_area() and through.intersects(rides)):
		return [m["vel"], through.get_center()]
	return []

## What a body going `speed` hands a rider it has walked into, which hangs
## `along` — the way its line lies when nothing moves it — with its middle
## `off` from the body's. A line neither stretches nor folds, so whatever of
## that speed runs the way the line hangs would move nothing: a body coming
## straight up under a lantern would go through it and leave it hanging
## still. A rider is a solid thing, and gives the way a solid thing does:
## that part of the push goes across instead, away from the body's middle —
## and one dead under the rider's middle picks a side rather than none. The
## body does not lift the lantern; it shoulders it aside.
static func glanced(speed: Vector2, along: Vector2, off: Vector2) -> Vector2:
	if along.is_zero_approx():
		return speed
	var line := along.normalized()
	var across := line.orthogonal()
	var side := -1.0 if off.dot(across) < 0.0 else 1.0
	return speed + across * side * absf(speed.dot(line))

func _physics_process(delta: float) -> void:
	step(delta)
	queue_redraw()

## The direction node `i` was hung in from its parent, which its children
## measure their rest angles from. The root has no parent, and its heading is
## its own `angle`.
func _heading(i: int) -> float:
	return float(nodes[i]["heading"])

## What moves through the world this frame, each as what it covers, in this
## node's space, with the speed it hands over and whose it is (`of`): the
## bodies — every actor going faster than PUSH_MIN — and the attacks in the
## air (`_attacks`). The video reads these off a buffer of every moving
## thing's speed at every pixel; for the handful a room holds, asking each is
## the same answer.
##
## A body the game has stopped is not moving, whatever speed it was stopped
## with. A line may go on swinging while the game is stopped — the hideout's
## scenery does, being weather — and a player paused halfway through a
## lantern would otherwise go on pushing it for as long as the menu was up.
func _movers() -> Array:
	var out: Array = []
	if not is_inside_tree():
		return out
	for a in get_tree().get_nodes_in_group("actors"):
		if not (a is CharacterBody2D) or not is_instance_valid(a) or a.is_queued_for_deletion():
			continue
		if not (a as Node).can_process():
			continue
		var vel: Vector2 = (a as CharacterBody2D).velocity
		if vel.length() < PUSH_MIN:
			continue
		var size = a.get("body_size")
		if not (size is Vector2):
			size = BODY_GUESS
		var at := to_local((a as Node2D).global_position)
		out.append({"rect": Rect2(at - (size as Vector2) * 0.5, size).grow(PUSH_REACH),
			"vel": vel.limit_length(push_most), "of": (a as Node).get_instance_id()})
	out.append_array(_attacks())
	return out

## What the attacks in the air hand a line, the way a body does — the video
## writes them into its buffer of speeds beside the bodies, and the foliage's
## buffer here has the bolts and the blasts (`VelocityBuffer`). They are
## whatever the world the arena holds has in it:
##
##   * a bolt, as the ball it is, all the way from where it was a step ago;
##   * a blast, as a ring opening from its centre and pushing outward, hardest
##     as it leaves;
##   * and what is over the moment it is made, for CUT_FOR from then: a lunge,
##     as whoever made it going down the path it cut; a beam, down its length;
##     a slash, across what it swept, the way it was aimed.
##
## Each at the kind's `push_most` and no more, as a body is. One the game has
## stopped is not moving, as a body is not.
func _attacks() -> Array:
	var out: Array = []
	var world := Arena.current()
	var flown := {}
	if world != null:
		for n in world.get_children():
			if not is_instance_valid(n) or n.is_queued_for_deletion() or not n.can_process():
				continue
			var whose := n.get_instance_id()
			if n is Projectile:
				var bolt := n as Projectile
				var at := to_local(bolt.global_position)
				out.append_array(_along(_bolts.get(whose, at), at,
					Vector2.ONE * (maxf(bolt.radius, float(S)) + PUSH_REACH), bolt.velocity, whose))
				flown[whose] = at
			elif n is AreaBurst:
				var blast := n as AreaBurst
				var opened := 1.0 - blast.life / maxf(blast.max_life, 0.001)
				out.append({"ring": to_local(blast.global_position), "r": blast.radius * opened,
					"wide": BLAST_RING + PUSH_REACH * 2.0, "speed": push_most * (1.0 - opened), "of": whose})
			elif n is DashSlash:
				var lunge := n as DashSlash
				if lunge.max_life - lunge.life <= CUT_FOR:
					var size = lunge.attacker.get("body_size") if is_instance_valid(lunge.attacker) else null
					out.append_array(_along(to_local(lunge.from), to_local(lunge.to),
						(size as Vector2 if size is Vector2 else BODY_GUESS) * 0.5 + Vector2.ONE * PUSH_REACH,
						(lunge.to - lunge.from).normalized() * push_most, whose))
			elif n is Zap:
				var beam := n as Zap
				if beam.max_life - beam.life <= CUT_FOR:
					out.append_array(_along(to_local(beam.from), to_local(beam.to),
						Vector2.ONE * (beam.half_width + PUSH_REACH), (beam.to - beam.from).normalized() * push_most, whose))
			elif n is MeleeArc:
				var slash := n as MeleeArc
				if slash.max_life - slash.life <= CUT_FOR:
					# The fan it swept, as nine squares of it: three out along
					# each of three spokes.
					var half := Vector2.ONE * (slash.reach * 0.2 + PUSH_REACH)
					for spoke: float in [-0.4, 0.0, 0.4]:
						for out_along: float in [0.3, 0.6, 0.9]:
							var spot := to_local(slash.global_position) \
								+ Vector2.from_angle(slash.aim + slash.arc * spoke) * slash.reach * out_along
							out.append({"rect": Rect2(spot - half, half * 2.0),
								"vel": Vector2.from_angle(slash.aim) * push_most, "of": whose})
	_bolts = flown
	return out

## Something going from `from` to `to` in a step, `half` its size either way,
## as a row of the rects it covered on the way, close enough together to leave
## no gap between two: each handing over `speed`, held to `push_most`, and all
## of them the one thing's, `whose`.
func _along(from: Vector2, to: Vector2, half: Vector2, speed: Vector2, whose: int) -> Array:
	var out: Array = []
	var steps := maxi(1, ceili(from.distance_to(to) / maxf(minf(half.x, half.y), 1.0)))
	for k in steps + 1:
		var at := from.lerp(to, float(k) / float(steps))
		out.append({"rect": Rect2(at - half, half * 2.0), "vel": speed.limit_length(push_most), "of": whose})
	return out

## Every rider put where its node is drawn: on that pixel's corner, and its
## own offset from there.
func _carry() -> void:
	for r in _riders:
		# Asked before it is called a node: a rider freed since it was attached
		# is not one any more.
		var rider = r["node"]
		var i: int = r["index"]
		if not is_instance_valid(rider) or i < 0 or i >= nodes.size():
			continue
		(rider as Node2D).global_position = Vector2(_pixel(nodes[i]["pos"])) * S + (r["offset"] as Vector2)

## The room what rides each node takes up, by the node's index, as a rect from
## where the node's riders are carried to: every rider with a body, and two on
## one node as the rect round both.
func _bodies() -> Dictionary:
	var out := {}
	for r in _riders:
		var body: Rect2 = r["body"]
		if not body.has_area() or not is_instance_valid(r["node"]):
			continue
		body.position += r["offset"]
		var i: int = r["index"]
		out[i] = (out[i] as Rect2).merge(body) if out.has(i) else body
	return out

## Whether anything rides node `i`.
func ridden(i: int) -> bool:
	for r in _riders:
		if int(r["index"]) == i and is_instance_valid(r["node"]):
			return true
	return false

## --- the picture ------------------------------------------------------------

## The line, pixel by pixel: Bresenham's from each node to its parent on the
## buffer's grid, each pixel a square S wide, so the line is one buffer pixel
## wide whichever way it lies — the video's mesh of pixels, drawn by hand. A
## free end gets a plug three pixels square, unless something rides it: a
## lantern is the end of its cord.
func _draw() -> void:
	for px in pixels():
		draw_rect(Rect2(_from_pixel(px), Vector2.ONE * S), color)
	for i in plugged():
		draw_rect(Rect2(_from_pixel(_pixel(nodes[i]["pos"]) - Vector2i.ONE), Vector2.ONE * S * 3), end_color)

## The free ends a plug is drawn on: every tip nothing rides.
func plugged() -> Array[int]:
	var out: Array[int] = []
	for i in tips():
		if not ridden(i):
			out.append(i)
	return out

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
