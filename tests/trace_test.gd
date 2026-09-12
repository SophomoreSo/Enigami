extends Node
## The editor must be able to say exactly where a board breaks.
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[TRACE] PASS ", what)
	else:
		fails += 1
		push_error("TRACE FAIL: " + what)

func _ready() -> void:
	# A flow entering a part from the side it does not point at is fine now:
	# the arrow says where flow leaves, nothing says where it may come from.
	var b := SkillBoard.new(7, 5, "sideways")
	b.place("INPUT", Vector2i(0, 2), 0)
	b.place("OVERCLOCK", Vector2i(1, 2), 1)      # entered from the west, leaves south
	b.place("OVERCLOCK", Vector2i(1, 3), 2)      # entered from the north, leaves west
	b.place("OVERCLOCK", Vector2i(0, 3), 1)      # entered from the east, leaves south
	b.place("SLASH", Vector2i(0, 4), 0)
	b.place("OUTPUT", Vector2i(1, 4), 0)
	var t := b.trace()
	check((t["breaks"] as Array).is_empty(), "turning a corner through any part is a valid join")
	check(t["reachable"].size() == 6, "the whole snaking chain is live")
	check(bool(t["reaches_output"]), "and it reaches the OUTPUT")
	var sim := SkillRunner.new(b)
	sim.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	check((sim.simulate()["outputs"] as Array).size() == 1, "it produces an attack")

	# Two outputs pointed at each other is the one join that cannot carry flow.
	var h := SkillBoard.new(7, 5, "headon")
	h.place("INPUT", Vector2i(0, 2), 0)
	h.place("WIRE", Vector2i(1, 2), 2)           # points back west at the INPUT
	var th := h.trace()
	check((th["breaks"] as Array).size() == 1, "outputs meeting head-on is a break")
	var msg := h.first_problem()
	print("[TRACE] message: ", msg)
	check(msg.contains("cannot meet"), "the message explains the head-on case")

	# Nothing may feed back into the INPUT.
	var fb := SkillBoard.new(7, 5, "feedback")
	fb.place("INPUT", Vector2i(1, 2), 0)
	fb.place("WIRE", Vector2i(2, 2), 1)
	fb.place("WIRE", Vector2i(2, 3), 2)
	fb.place("WIRE", Vector2i(1, 3), 3)          # points north, back at the INPUT
	var ti := fb.trace()
	check((ti["breaks"] as Array).size() == 1, "a flow aimed at the INPUT is refused")

	# A ring must not run forever: a pulse gets a hop budget.
	var r := SkillBoard.new(7, 5, "ring")
	r.place("INPUT", Vector2i(0, 0), 0)          # feeds east into the ring
	r.place("WIRE", Vector2i(1, 0), 0)           # east
	r.place("WIRE", Vector2i(2, 0), 1)           # south
	r.place("WIRE", Vector2i(2, 1), 2)           # west
	r.place("WIRE", Vector2i(1, 1), 3)           # north, closing the ring
	var tr := r.trace()
	check((tr["breaks"] as Array).is_empty(), "a ring is a legal board")
	check(tr["reachable"].size() == 5, "the whole ring is reachable")
	var runner := SkillRunner.new(r)
	runner.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	runner.set_active(true)
	runner._tick()                               # starts the cycle
	check(not runner.is_idle(), "the ring pulse is in flight")
	var ticks := 1
	while ticks < 4000 and not runner.is_idle():
		runner._tick()
		ticks += 1
	check(runner.is_idle(), "the circulating pulse burns out (%d ticks)" % ticks)
	check(ticks > 10, "but not immediately — it really did circulate")
	# And the board recovers: the next cycle starts normally afterwards.
	var restarted := false
	for i in 200:
		runner._tick()
		if not runner.is_idle():
			restarted = true
			break
	check(restarted, "the board starts a fresh cycle after a ring burns out")

	# Flow into the tail half of a two-cell part is a break, not a connection.
	var c := SkillBoard.new(7, 5, "tail")
	c.place("INPUT", Vector2i(0, 0), 1)          # points south
	c.place("AREA", Vector2i(0, 1), 1)           # turned to face north; tail at 0,2
	var t2 := c.trace()
	check((t2["breaks"] as Array).is_empty(), "entering a two-cell head is fine")
	check(t2["reachable"].size() == 2, "and the two-cell part is reachable")
	var d := SkillBoard.new(7, 5, "tail2")
	d.place("INPUT", Vector2i(1, 0), 1)          # points south into the TAIL cell
	d.place("AREA", Vector2i(0, 1), 0)
	var t3 := d.trace()
	check((t3["breaks"] as Array).size() == 1, "entering a two-cell tail is a break")
	check(d.first_problem().contains("tail"), "and the message explains it")

	# A flow running into empty space is a leak, not a break.
	var e := SkillBoard.new(7, 5, "leak")
	e.place("INPUT", Vector2i(0, 2), 0)
	var t4 := e.trace()
	check((t4["leaks"] as Array).size() == 1, "a dangling output is reported as a leak")
	check(e.first_problem().contains("finds nothing"), "and the message says so")

	# No INPUT at all.
	var f := SkillBoard.new(7, 5, "noinput")
	f.place("SLASH", Vector2i(2, 2), 0)
	check(f.first_problem().contains("No INPUT"), "a board with no INPUT says so")

	# A wired board with no attack form reports that, not a wiring fault.
	var g := SkillBoard.new(7, 5, "noform")
	g.place("INPUT", Vector2i(0, 2), 0)
	g.place("WIRE", Vector2i(1, 2), 0)
	g.place("OUTPUT", Vector2i(2, 2), 0)
	check(g.first_problem().contains("no attack form"), "a formless chain says what is missing")

	print("[TRACE] ---- %d failures ----" % fails)
	get_tree().quit()
