extends Node
## A rope: the line of nodes from aarthificial's Legacy devlog #21, the
## tables its kinds and their numbers are read from, and the cables a room
## hangs from it.
##
## A kind of line is made with its row's numbers, and a kind that is not
## there is said and hangs as a cable. Bresenham's line comes out whole and
## 8-connected however it lies. A cable hung from a point settles straight
## under its anchor, hardly longer than it was made; a push swings what hangs
## below it and draws what is above after it, up to the anchor, and dies
## away; a fixed node never moves; a line pulls on what it hangs from and
## cannot push it, and a bend is felt by the node before it; a line comes to
## rest whatever numbers it is given; a stiff wire sags less than a loose
## one, and not at all without gravity; a branch keeps its angle; a rider
## follows its node; a body moving through the line hands it speed, and one
## standing still or elsewhere hands it none — and a body through the end of
## a cable swings all of it, from the anchor down. A room hangs what the
## `hangings` rows say, as many and as long, from rock with open air under
## them, the same ones every time it is built. And what the schema promises
## to refuse is tried against a scratch copy.
##
## No renderer needed: the simulation is stepped by hand, and the pixels are
## asked for rather than drawn. The refusals print an `SQL error` line each
## from the extension, which is the point of them.

const DT := 1.0 / 60.0
const SRC := "res://data/db"
const SCRATCH := "user://rope_test.db"

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[ROPE] PASS ", what)
	else:
		fails += 1
		push_error("ROPE FAIL: " + what)

func run(rope: Rope, steps: int) -> void:
	for i in steps:
		rope.step(DT)

func _ready() -> void:
	_table()
	_bresenham()
	_hanging()
	_pushed()
	_handed_up()
	_at_rest()
	_stiff()
	_branch_and_rider()
	_movers()
	_rooms()
	_refusals()
	print("[ROPE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- the table --------------------------------------------------------------

func _table() -> void:
	check(Db.available(), "the database opens (%s)" % Db.PATH)
	for table in ["ropes", "hangings"]:
		check(Db.has_table(table), "there is a table of %s" % table)
	check(Db.meta("schema_version") == str(Db.SCHEMA_VERSION),
		"the database is at the schema the code reads (file says %s, code says %d)"
			% [Db.meta("schema_version"), Db.SCHEMA_VERSION])
	var kinds := Rope.kinds()
	check(kinds.has("cable"), "a cable is a kind of line (%s)" % str(kinds))
	var row := Rope.source("cable")
	var cable := Rope.of("cable")
	check(cable.kind == "cable" and not row.is_empty()
			and cable.segment == float(row.get("segment", -1)) and cable.stiffness == float(row.get("stiffness", -1))
			and cable.damping == float(row.get("damping", -1)) and cable.gravity == float(row.get("gravity", -1))
			and cable.give == float(row.get("give", -1)) and cable.push_most == float(row.get("push_most", -1)),
		"a cable is made with its row's numbers (%s)" % str(row))
	cable.hang(Vector2.ZERO, 96.0)
	check(cable.nodes.size() == 1 + int(round(96.0 / float(row.get("segment", 1)))),
		"and hung with its nodes its row's segment apart (%d)" % cable.nodes.size())
	var plain := Rope.new()
	var none := Rope.of("nowhere")
	check(none.kind == "cable" and none.stiffness == plain.stiffness and none.segment == plain.segment,
		"a kind that is not there is said above, and hangs as a cable")
	var rows := Rope.hangings()
	check(rows.size() >= 1 and String(rows[0].get("rope", "")) == "cable",
		"the rooms hang cables (%s)" % str(rows))
	cable.free()
	plain.free()
	none.free()

## --- the line ---------------------------------------------------------------

func _bresenham() -> void:
	var flat := Rope.bresenham(Vector2i(0, 0), Vector2i(5, 0))
	check(flat.size() == 6 and flat[0] == Vector2i(0, 0) and flat[5] == Vector2i(5, 0),
		"a flat line is every pixel from a to b (%s)" % str(flat))
	var diag := Rope.bresenham(Vector2i(0, 0), Vector2i(3, 3))
	check(diag.size() == 4 and diag[2] == Vector2i(2, 2), "a diagonal steps a pixel each way (%s)" % str(diag))
	var back := Rope.bresenham(Vector2i(3, 3), Vector2i(0, 0))
	check(back.size() == 4 and back[0] == Vector2i(3, 3) and back[3] == Vector2i.ZERO,
		"and reads the same backwards")
	for pair in [[Vector2i(0, 0), Vector2i(6, 2)], [Vector2i(-3, 7), Vector2i(4, -9)],
			[Vector2i(2, 2), Vector2i(2, 2)], [Vector2i(0, 0), Vector2i(1, -5)]]:
		var a: Vector2i = pair[0]
		var b: Vector2i = pair[1]
		var line := Rope.bresenham(a, b)
		var want := maxi(absi(b.x - a.x), absi(b.y - a.y)) + 1
		var connected := true
		for i in range(1, line.size()):
			var d: Vector2i = (line[i] - line[i - 1]).abs()
			if d.x > 1 or d.y > 1 or d == Vector2i.ZERO:
				connected = false
		check(line.size() == want and connected and line[0] == a and line[line.size() - 1] == b,
			"%s to %s is %d pixels, each touching the last (%d)" % [str(a), str(b), want, line.size()])

## --- a cable ----------------------------------------------------------------

func _hanging() -> void:
	var rope := Rope.new()
	var anchor := Vector2(200, 64)
	rope.hang(anchor, 80.0, 16.0)
	check(rope.nodes.size() == 6, "a cable 80 long at 16 a node is a root and five nodes (%d)" % rope.nodes.size())
	check(rope.point_of(5).is_equal_approx(anchor + Vector2(0, 80)),
		"hung straight down to start (%s)" % str(rope.point_of(5)))
	var ends := rope.tips()
	check(ends.size() == 1 and ends[0] == 5, "with one free end, the last node (%s)" % str(ends))
	# Knocked askew, then left alone for a quarter of a minute.
	for i in range(1, 6):
		rope.nodes[i]["pos"] += Vector2(30.0 * i, 0.0)
	run(rope, 900)
	var tip := rope.point_of(5)
	check(absf(tip.x - anchor.x) < 0.5 and tip.y > anchor.y + 79.5 and tip.y < anchor.y + 92.0,
		"left alone it hangs straight under its anchor again, no longer than it was made (%s)" % str(tip))
	check(rope.point_of(0) == anchor, "the anchor never moves")
	var fastest := 0.0
	for i in range(1, 6):
		fastest = maxf(fastest, (rope.nodes[i]["vel"] as Vector2).length())
	check(fastest < 0.5, "and it has come to rest (%.3f a second)" % fastest)
	var px := rope.pixels()
	check(px.size() >= 40 and px.size() <= 47 and px[0] == Vector2i(100, 32),
		"drawn, it is one pixel for every buffer pixel of its length, from its anchor down (%d from %s)"
			% [px.size(), str(px[0])])
	var in_column := true
	for p in px:
		if absi(p.x - 100) > 1:
			in_column = false
	check(in_column, "all of them in the anchor's column")
	rope.free()

func _pushed() -> void:
	var rope := Rope.new()
	rope.hang(Vector2(100, 0), 96.0, 16.0)
	rope.nudge(3, Vector2(400, 0))
	run(rope, 6)
	check(rope.point_of(3).x > 108.0, "a push moves the node pushed (%s)" % str(rope.point_of(3)))
	check(rope.point_of(4).x > 101.0, "and what hangs under it swings after it (%s)" % str(rope.point_of(4)))
	check(rope.point_of(1).x > 100.5 and rope.point_of(2).x > rope.point_of(1).x,
		"and what is above it is drawn after it, the less the nearer the anchor (%s, %s)"
			% [str(rope.point_of(1)), str(rope.point_of(2))])
	var swung := 0.0
	for i in 120:
		rope.step(DT)
		swung = maxf(swung, absf(rope.point_of(6).x - 100.0))
	check(swung > 5.0, "the free end swings out in the second after (%.1f)" % swung)
	run(rope, 900)
	check(absf(rope.point_of(6).x - 100.0) < 0.5, "and it settles under the anchor again (%s)" % str(rope.point_of(6)))
	rope.nudge(0, Vector2(400, 0))
	run(rope, 10)
	check(rope.point_of(0) == Vector2(100, 0), "a fixed node cannot be pushed")
	rope.nudge(5, Vector2(5000, 0))
	var was := rope.point_of(5)
	rope.step(DT)
	check(rope.point_of(5).distance_to(was) <= Rope.MOST_A_STEP * 16.0 + 0.01,
		"however hard it is shoved, a node moves no further in a step than %.0f%% of its segment (%.1f)"
			% [Rope.MOST_A_STEP * 100.0, rope.point_of(5).distance_to(was)])
	rope.free()
	# A long cable shoved hard in the middle: it swings, it never rises over
	# its anchor, it never stretches, and it settles. A chain of springs did
	# none of these: each node swung harder than the one above it.
	var long := Rope.new()
	long.hang(Vector2(100, 0), 240.0, 12.0)
	long.nudge(8, Vector2(600, 0))
	long.nudge(9, Vector2(600, 0))
	var risen := false
	var stretched := 0.0
	var swung_far := 0.0
	for i in 1500:
		long.step(DT)
		for k in range(1, long.nodes.size()):
			if long.point_of(k).y < -4.0:
				risen = true
			stretched = maxf(stretched, absf(long.point_of(k).distance_to(
				long.point_of(int(long.nodes[k]["parent"]))) - 12.0))
		swung_far = maxf(swung_far, absf(long.point_of(20).x - 100.0))
	check(not risen and stretched < 0.01 and swung_far > 10.0 and absf(long.point_of(20).x - 100.0) < 2.0,
		"a long cable shoved hard swings, never rises over its anchor or stretches, and settles (swung %.0f, stretched %.3f, ends at %s)"
			% [swung_far, stretched, str(long.point_of(20))])
	long.free()

## What holds a node to its parent, the parent is handed the other half of.
## A corner with nothing to move it — no weight, no shape to keep — so
## anything that moves was moved by the line.
func _corner() -> Rope:
	var rope := Rope.new()
	rope.gravity = 0.0
	rope.stiffness = 0.0
	var top := rope.root(Vector2.ZERO, PI * 0.5)
	var knee := rope.add_node(top, 0.0, 16.0)
	rope.add_node(knee, -PI * 0.5, 16.0)
	return rope

func _handed_up() -> void:
	var slack := _corner()
	run(slack, 10)
	check(slack.point_of(1).is_equal_approx(Vector2(0, 16)) and slack.point_of(2).is_equal_approx(Vector2(16, 16)),
		"a corner with nothing pulling on it lies as it was made (%s, %s)" % [str(slack.point_of(1)), str(slack.point_of(2))])
	slack.nudge(2, Vector2(-200, 0))
	var knee_moved := 0.0
	for i in 10:
		slack.step(DT)
		knee_moved = maxf(knee_moved, slack.point_of(1).distance_to(Vector2(0, 16)))
	check(knee_moved < 0.001 and slack.point_of(2).is_equal_approx(Vector2(16, 16)),
		"a node shoved at its parent is put back at its length, and the parent never feels it: a line cannot push (%.4f)"
			% knee_moved)
	var taut := _corner()
	taut.nudge(2, Vector2(200, 0))
	run(taut, 4)
	check(taut.point_of(1).x > 0.5,
		"a node pulled away from its parent draws the parent after it (%s)" % str(taut.point_of(1)))
	check(absf(taut.point_of(1).length() - 16.0) < 0.01 and absf(taut.point_of(2).distance_to(taut.point_of(1)) - 16.0) < 0.01,
		"each still exactly as far from its parent as it was made")
	slack.free()
	taut.free()
	# The shape's pull has two ends as well: a bend at the end of a weightless
	# wire draws the node before it toward the bend, and then all of it is
	# back where it was made.
	var bent := _wire(30.0, 0.0)
	bent.nudge(5, Vector2(0, 200))
	run(bent, 3)
	check(bent.point_of(4).y > 0.05 and bent.point_of(5).y > bent.point_of(4).y,
		"a bend at the end of a wire is felt by the node before it (%s, %s)"
			% [str(bent.point_of(4)), str(bent.point_of(5))])
	run(bent, 600)
	var out_of_line := 0.0
	for i in range(1, 6):
		out_of_line = maxf(out_of_line, bent.point_of(i).distance_to(Vector2(16.0 * i, 0)))
	check(out_of_line < 0.01, "and the wire is back as it was made (%.4f)" % out_of_line)
	bent.free()
	# The weight of what hangs from a node reaches it too: the top of a cable
	# is pulled on by all of it, the end by nothing.
	var hung := Rope.new()
	hung.hang(Vector2.ZERO, 96.0, 16.0)
	run(hung, 60)
	var weight := Vector2(0.0, hung.gravity * DT)
	check(((hung.nodes[1]["pull"] as Vector2) / weight.y).is_equal_approx(Vector2(0, 5) * exp(-hung.damping * DT))
			and (hung.nodes[6]["pull"] as Vector2) == Vector2.ZERO,
		"a hanging node is pulled on by the weight of everything under it, and the end by nothing (%s, %s)"
			% [str(hung.nodes[1]["pull"]), str(hung.nodes[6]["pull"])])
	check(hung.point_of(6).is_equal_approx(Vector2(0, 96)),
		"and hangs where it was hung all the same (%s)" % str(hung.point_of(6)))
	hung.free()

## Numbers a line used to thrash at for good, each node swinging harder than
## the one above it: knocked hard, it is still inside half a minute.
func _at_rest() -> void:
	for numbers in [[8.0, 1.0, 0.3, 200.0], [12.0, 3.0, 0.3, 0.0], [4.0, 8.0, 0.8, 200.0]]:
		for wire in [false, true]:
			var rope := Rope.new()
			rope.segment = numbers[0]
			rope.stiffness = numbers[1]
			rope.damping = numbers[2]
			rope.gravity = numbers[3]
			if wire:
				var last := rope.root(Vector2.ZERO, 0.0)
				for i in int(120.0 / rope.segment):
					last = rope.add_node(last, 0.0, rope.segment)
			else:
				rope.hang(Vector2.ZERO, 120.0)
			for i in range(1, rope.nodes.size()):
				rope.nudge(i, Vector2(160.0 * sin(i * 0.7), 60.0 * cos(i * 0.4)))
			run(rope, 1800)
			var fastest := 0.0
			for i in range(1, rope.nodes.size()):
				fastest = maxf(fastest, (rope.nodes[i]["vel"] as Vector2).length())
			check(fastest < 0.5, "a %s knocked hard comes to rest: segment %.0f, stiffness %.0f, damping %.1f, gravity %.0f (%.2f a second)"
				% ["wire" if wire else "cable", numbers[0], numbers[1], numbers[2], numbers[3], fastest])
			rope.free()

## A wire out from a wall: what stiffness and gravity do to it.
func _wire(stiffness: float, gravity: float) -> Rope:
	var rope := Rope.new()
	rope.stiffness = stiffness
	rope.gravity = gravity
	var last := rope.root(Vector2.ZERO, 0.0)
	for i in 5:
		last = rope.add_node(last, 0.0, 16.0)
	return rope

func _stiff() -> void:
	var loose := _wire(1.0, 900.0)
	var stiff := _wire(30.0, 900.0)
	run(loose, 900)
	run(stiff, 900)
	check(loose.point_of(5).y > stiff.point_of(5).y + 2.0 and stiff.point_of(5).y > 0.0,
		"a wire sags under gravity, and a stiff one sags less (%.1f against %.1f)"
			% [loose.point_of(5).y, stiff.point_of(5).y])
	check(absf(loose.point_of(5).distance_to(loose.point_of(4)) - 16.0) < 0.01,
		"however it sags, a node stays exactly as far from its parent as it was made (%.2f)"
			% loose.point_of(5).distance_to(loose.point_of(4)))
	var weightless := _wire(1.0, 0.0)
	run(weightless, 300)
	check(weightless.point_of(5).is_equal_approx(Vector2(80, 0)),
		"and without gravity a wire lies exactly as it was made (%s)" % str(weightless.point_of(5)))
	loose.free()
	stiff.free()
	weightless.free()

func _branch_and_rider() -> void:
	var rope := Rope.new()
	rope.gravity = 0.0
	rope.hang(Vector2.ZERO, 32.0, 16.0)
	var arm := rope.add_node(1, -PI * 0.5, 10.0)
	check(arm == 3 and rope.point_of(arm).is_equal_approx(Vector2(10, 16)),
		"a branch hangs off any node, at its own angle from that node's heading (%s)" % str(rope.point_of(arm)))
	var ends := rope.tips()
	check(ends.size() == 2 and ends[0] == 2 and ends[1] == 3, "and the line has two free ends (%s)" % str(ends))
	run(rope, 300)
	check(rope.point_of(arm).is_equal_approx(Vector2(10, 16)) and rope.point_of(2).is_equal_approx(Vector2(0, 32)),
		"and stays there, with the line under its node unmoved")
	add_child(rope)
	rope.set_physics_process(false)
	var lamp := Node2D.new()
	add_child(lamp)
	rope.attach(lamp, 2, Vector2(0, 4))
	check(lamp.global_position.is_equal_approx(Vector2(0, 36)),
		"a rider is carried to its node the moment it is attached (%s)" % str(lamp.global_position))
	rope.nudge(2, Vector2(300, 0))
	rope.step(DT)
	check(lamp.global_position.is_equal_approx(rope.point_of(2) + Vector2(0, 4)) and lamp.global_position.x > 1.0,
		"and follows it as it moves (%s)" % str(lamp.global_position))
	lamp.free()
	rope.free()

## --- bodies -----------------------------------------------------------------

func _hung_here(at: Vector2) -> Rope:
	var rope := Rope.new()
	add_child(rope)
	rope.set_physics_process(false)
	rope.hang(at, 96.0, 16.0)
	return rope

func _movers() -> void:
	var walker := Actor.new()
	add_child(walker)
	var rope := _hung_here(Vector2(300, 100))
	walker.global_position = rope.point_of(3)
	walker.velocity = Vector2(250, 0)
	rope.step(DT)
	check((rope.nodes[3]["vel"] as Vector2).x > 50.0 and absf((rope.nodes[1]["vel"] as Vector2).x) < 0.01,
		"a body walking through the line hands the node it covers some of its speed, and none to one it does not (%s, %s)"
			% [str(rope.nodes[3]["vel"]), str(rope.nodes[1]["vel"])])
	for i in 4:
		rope.step(DT)
	check((rope.nodes[1]["vel"] as Vector2).x > 5.0,
		"the line hands it on from there: a few frames later the node under the anchor is moving too (%s)"
			% str(rope.nodes[1]["vel"]))
	# The whole of a walk through the end of a cable: the body covers the last
	# two nodes and nothing else, and every node above them swings out after
	# it, each further than the one over it — the anchor alone stays put.
	var swung := _hung_here(Vector2(300, 100))
	var reach: Array = []
	for i in swung.nodes.size():
		reach.append(0.0)
	walker.velocity = Vector2(250, 0)
	walker.global_position = swung.point_of(6) + Vector2(-60, -12)
	var touched := {}
	for k in 90:
		if k < 30:
			walker.global_position += walker.velocity * DT
			var body := Rect2(walker.global_position - walker.body_size * 0.5, walker.body_size).grow(Rope.PUSH_REACH)
			for i in swung.nodes.size():
				if body.has_point(swung.point_of(i)):
					touched[i] = true
		else:
			walker.global_position = Vector2(900, 900)
		swung.step(DT)
		for i in swung.nodes.size():
			reach[i] = maxf(reach[i], absf(swung.point_of(i).x - 300.0))
	var rising := true
	for i in range(1, swung.nodes.size()):
		if reach[i] <= reach[i - 1]:
			rising = false
	check(not touched.has(1) and not touched.has(2) and not touched.has(3) and touched.has(6),
		"a body walking through the end of a cable touches the end of it and not the top (%s)" % str(touched.keys()))
	check(reach[0] == 0.0 and reach[1] > 2.0 and rising,
		"and the whole cable swings out after it, from the node under the anchor down, each further than the one over it (%s)"
			% str(reach.map(func(r: float) -> String: return "%.1f" % r)))
	swung.free()
	var idle := _hung_here(Vector2(300, 100))
	walker.global_position = idle.point_of(3)
	walker.velocity = Vector2(10, 0)
	idle.step(DT)
	check(absf((idle.nodes[3]["vel"] as Vector2).x) < 0.01,
		"a body standing in the line, slower than %.0f, moves nothing" % Rope.PUSH_MIN)
	walker.global_position = Vector2(900, 900)
	walker.velocity = Vector2(500, 0)
	idle.step(DT)
	check(absf((idle.nodes[3]["vel"] as Vector2).x) < 0.01, "nor does one moving somewhere else")
	# A body at a stone's speed — a dash, a fall — hands over a walk's worth
	# and no more, and a fall up or down through the line folds nothing.
	var struck := _hung_here(Vector2(300, 100))
	walker.global_position = struck.point_of(3)
	walker.velocity = Vector2(880, 0)
	struck.step(DT)
	check((struck.nodes[3]["vel"] as Vector2).length() <= struck.push_most * 0.35 + 0.5,
		"a dash hands over no more than %.0f a second's worth (%.0f)"
			% [struck.push_most, (struck.nodes[3]["vel"] as Vector2).length()])
	var fallen := _hung_here(Vector2(300, 100))
	var folded := false
	for through in [Vector2(40, -900), Vector2(40, 900)]:
		walker.global_position = fallen.point_of(5) + Vector2(0, 30) * signf(-through.y)
		walker.velocity = through
		for i in 12:
			walker.global_position += through * DT
			fallen.step(DT)
			for k in range(1, fallen.nodes.size()):
				var seg := fallen.point_of(k) - fallen.point_of(int(fallen.nodes[k]["parent"]))
				if seg.y < 0.0 or absf(seg.length() - 16.0) > 0.01:
					folded = true
	check(not folded, "a body jumping up through the line and falling back down it folds no node over its parent")
	walker.free()
	rope.free()
	idle.free()
	struck.free()
	fallen.free()

## --- a room -----------------------------------------------------------------

func _room(record: Dictionary, seed_base: int) -> Room:
	var room := Room.new()
	add_child(room)
	room.build(Vector2i.ZERO, record.duplicate(true), {}, seed_base)
	return room

func _anchors(view: RoomView) -> Array:
	var out: Array = []
	for rope: Rope in view.ropes:
		out.append(rope.point_of(0))
	return out

func _rooms() -> void:
	var record := {"kind": "entry", "danger": 1, "region": 0, "variant": 7, "enemies": [], "loot": []}
	var a := _room(record, 12345)
	var view := Views.of(a) as RoomView
	check(view != null and not view.ropes.is_empty(),
		"a room hangs cables when it is built (%d)" % (0 if view == null else view.ropes.size()))
	if view != null:
		for rope: Rope in view.ropes:
			var top: Vector2 = rope.point_of(0)
			var cell := Vector2i(int(floor(top.x / Room.CELL)), int(floor(top.y / Room.CELL)))
			check(a.is_solid(cell.x, cell.y - 1) and not a.is_solid(cell.x, cell.y),
				"a cable hangs from rock into open air (%s)" % str(cell))
			var tip: Vector2 = rope.point_of(rope.nodes.size() - 1)
			check(not a.is_solid_at(tip) and not a.is_solid_at(tip + Vector2(0, Room.CELL)),
				"and stops short of the floor (%s)" % str(tip))
			check(fmod(top.x, float(Rope.S)) == 0.0 and fmod(top.y, float(Rope.S)) == 0.0,
				"anchored on the pixel grid (%s)" % str(top))
			check(rope.get_parent() == view and rope.z_index == -1,
				"under the room's view, behind everything that moves")
		for row in Rope.hangings():
			var kind := String(row["rope"])
			var of_kind: Array = view.ropes.filter(func(r: Rope) -> bool: return r.kind == kind)
			check(of_kind.size() >= int(row["fewest"]) and of_kind.size() <= int(row["most"]),
				"the room hangs as many of kind %s as its row says, %d to %d (%d)"
					% [kind, int(row["fewest"]), int(row["most"]), of_kind.size()])
			var sized := true
			for r: Rope in of_kind:
				var long := (r.nodes.size() - 1) * r.segment
				if long < int(row["shortest"]) * Room.CELL - r.segment * 0.5 - 0.01 \
						or long > int(row["longest"]) * Room.CELL + r.segment * 0.5 + 0.01:
					sized = false
			check(sized, "each %d to %d cells long, to the nearest node" % [int(row["shortest"]), int(row["longest"])])
		var b := _room(record, 12345)
		var vb := Views.of(b) as RoomView
		check(vb != null and _anchors(vb) == _anchors(view),
			"the same room hangs the same cables every time it is built (%s)" % str(_anchors(view)))
		var flat := _room({"kind": "entry", "danger": 1, "region": 0, "variant": 3,
			"flat": true, "enemies": [], "loot": []}, 20260920)
		var vf := Views.of(flat) as RoomView
		var from_ceiling := vf != null and not vf.ropes.is_empty()
		if vf != null:
			for rope: Rope in vf.ropes:
				if rope.point_of(0).y != float(Room.CELL):
					from_ceiling = false
		check(from_ceiling, "a flat room hangs its cables from the ceiling, having nothing else (%s)"
			% ("" if vf == null else str(_anchors(vf))))
		b.free()
		flat.free()
	a.free()

## --- what the schema refuses ------------------------------------------------

func _refusals() -> void:
	var db = _scratch()
	if db == null:
		check(false, "a scratch copy of the schema can be made to try it against")
		return
	var kind := "INSERT INTO ropes (id, segment, stiffness, damping, gravity, give, push_most) VALUES ('chain', 16, 1, 0.5, 1200, 0.2, 180)"
	var hang := "INSERT INTO hangings (rope, fewest, most, shortest, longest) VALUES ('chain', 0, 1, 2, 4)"
	check(_accepted(db, [kind, hang]), "a second kind of line, and the rooms hanging it, are accepted (%s)" % db.error_message)
	check(not _accepted(db, [kind.replace("0.5, 1200", "-0.5, 1200")]), "a damping under nothing is refused")
	check(not _accepted(db, [kind.replace("0.2, 180", "1.2, 180")]), "a give past all of a body's speed is refused")
	check(not _accepted(db, [kind.replace("'chain', 16", "'chain', 1")]), "nodes closer than two pixels are refused")
	check(not _accepted(db, [kind.replace("'chain'", "'Chain'")]), "a kind not in lower case is refused")
	check(not _accepted(db, [kind, hang.replace("0, 1, 2, 4", "2, 1, 2, 4")]), "a most under a fewest is refused")
	check(not _accepted(db, [kind, hang.replace("2, 4)", "4, 2)")]), "a longest under a shortest is refused")
	check(not _accepted(db, [kind, hang.replace("2, 4)", "0, 4)")]), "a line no cells long is refused")
	check(not _accepted(db, [hang]), "hanging a kind of line that is not there is refused")
	db.close_db()
	DirAccess.remove_absolute(SCRATCH)

## A fresh database with the real schema in it, foreign keys on, or null.
func _scratch():
	if not ClassDB.class_exists("SQLite"):
		return null
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(SCRATCH)
	var db = ClassDB.instantiate("SQLite")
	db.path = SCRATCH
	db.foreign_keys = true
	db.verbosity_level = 0
	if not db.open_db():
		push_error("ROPE: could not open %s: %s" % [SCRATCH, db.error_message])
		return null
	var schema := FileAccess.get_file_as_string(SRC.path_join("schema.sql"))
	if schema == "" or not db.query(schema):
		push_error("ROPE: the schema did not run: %s" % db.error_message)
		return null
	return db

## Whether `statements` go in and commit, the way build.sh commits them. What
## went in is taken out again afterwards, so every try starts from nothing.
func _accepted(db, statements: Array) -> bool:
	var ok: bool = db.query("BEGIN")
	for st in statements:
		ok = ok and db.query(st)
	ok = ok and db.query("COMMIT")
	if not ok:
		db.query("ROLLBACK")
		return false
	db.query("DELETE FROM ropes")
	return true
