extends Node
## A rope: the line of nodes from aarthificial's Legacy devlog #21, and the
## cables a room hangs from it.
##
## Bresenham's line comes out whole and 8-connected however it lies. A cable
## hung from a point settles straight under its anchor, hardly longer than it
## was made; a push bends what hangs below it and nothing above, and dies
## away; a fixed node never moves; a stiff wire sags less than a loose one,
## and not at all without gravity; a branch keeps its angle; a rider follows
## its node; a body moving through the line hands it speed, and one standing
## still or elsewhere hands it none. And a room hangs its cables from rock
## with open air under them, the same ones every time it is built.
##
## No renderer needed: the simulation is stepped by hand, and the pixels are
## asked for rather than drawn.

const DT := 1.0 / 60.0

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
	_bresenham()
	_hanging()
	_pushed()
	_stiff()
	_branch_and_rider()
	_movers()
	_rooms()
	print("[ROPE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

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
	check(absf(rope.point_of(1).x - 100.0) < 0.01 and absf(rope.point_of(2).x - 100.0) < 0.01,
		"and nothing above it feels it: the anchor holds the line taut over the push (%s, %s)"
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
	walker.free()
	rope.free()
	idle.free()

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
