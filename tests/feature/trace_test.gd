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
	h.place("DELAY", Vector2i(1, 2), 2)          # points back west at the INPUT
	var th := h.trace()
	check((th["breaks"] as Array).size() == 1, "outputs meeting head-on is a break")
	var msg := h.first_problem()
	print("[TRACE] message: ", msg)
	# The break is named at the part that would not take the flow — the DELAY
	# turned back on the INPUT — not at the one that sent it.
	check(msg == Loc.t("editor.problem.head_on", [Components.name_for("DELAY"), 1, 2]),
		"the message explains the head-on case")

	# Nothing may feed back into the INPUT.
	var fb := SkillBoard.new(7, 5, "feedback")
	fb.place("INPUT", Vector2i(1, 2), 0)
	fb.place("DELAY", Vector2i(2, 2), 1)
	fb.place("DELAY", Vector2i(2, 3), 2)
	fb.place("DELAY", Vector2i(1, 3), 3)         # points north, back at the INPUT
	var ti := fb.trace()
	check((ti["breaks"] as Array).size() == 1, "a flow aimed at the INPUT is refused")

	# A ring must not run forever: a pulse gets a hop budget.
	var r := SkillBoard.new(7, 5, "ring")
	r.place("INPUT", Vector2i(0, 0), 0)          # feeds east into the ring
	r.place("DELAY", Vector2i(1, 0), 0)          # east
	r.place("DELAY", Vector2i(2, 0), 1)          # south
	r.place("DELAY", Vector2i(2, 1), 2)          # west
	r.place("DELAY", Vector2i(1, 1), 3)          # north, closing the ring
	var tr := r.trace()
	check((tr["breaks"] as Array).is_empty(), "a ring is a legal board")
	check(tr["reachable"].size() == 5, "the whole ring is reachable")
	var runner := SkillRunner.new(r)
	runner.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	# Charged, so the ring is given real life to burn through rather than the
	# single pass an uncharged cast is worth.
	runner.ttl_bonus = 40
	runner.set_active(true)
	runner._tick()                               # starts the cycle
	check(not runner.is_idle(), "the ring pulse is in flight")
	var ticks := 1
	while ticks < 4000 and not runner.is_idle():
		runner._tick()
		ticks += 1
	check(runner.is_idle(), "the circulating pulse burns out (%d ticks)" % ticks)
	check(ticks > 4, "but not immediately — it really did circulate")
	# And the board recovers: the next cycle starts normally afterwards.
	var restarted := false
	for i in 200:
		runner._tick()
		if not runner.is_idle():
			restarted = true
			break
	check(restarted, "the board starts a fresh cycle after a ring burns out")

	# The budget counts re-entries into a part, and it is the same budget the
	# workbench previews with. A looping board therefore has to run at the cycle
	# time and shot count the preview promised: when the runner counted total
	# distance travelled instead, a ring held the cycle open for dozens of ticks
	# with INPUT stuck behind it, and the board fired once where the preview
	# said four.
	var lp := SkillBoard.new(7, 5, "loop")
	lp.place("INPUT", Vector2i(0, 1), 0)
	lp.place("DELAY", Vector2i(1, 1), 3)
	lp.place("DELAY", Vector2i(1, 0), 0)
	lp.place("DELAY", Vector2i(2, 0), 0)
	lp.place("DELAY", Vector2i(3, 0), 1)
	lp.place("DELAY", Vector2i(3, 1), 2)
	lp.place("TEE", Vector2i(2, 1), 1)      # round the ring, and out to the attack
	lp.place("SLASH", Vector2i(2, 2), 0)
	lp.place("OUTPUT", Vector2i(3, 2), 0)
	var lr := SkillRunner.new(lp)
	lr.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	# An uncharged cast is worth one pass, so the laps this is checking are
	# bought the way a player buys them: by holding the cast button.
	lr.ttl_bonus = 32
	var pred := lr.simulate()
	var predicted := float(pred["cycle_seconds"])
	var want_shots: int = (pred["outputs"] as Array).size()
	check(want_shots > 1, "the ring previews more than one shot per cycle (%d)" % want_shots)
	var cycles := [0]
	var shots := [0]
	var whole := [0]   # shots banked at the last cycle boundary, so no partial cycle
	lr.cycle_started.connect(func() -> void:
		cycles[0] += 1
		whole[0] = shots[0])
	lr.fired.connect(func(_p: Payload) -> void: shots[0] += 1)
	lr.set_active(true)
	var step := 1.0 / 240.0
	var elapsed := 0.0
	while elapsed < predicted * 5.0:
		lr.update(step)
		elapsed += step
	var measured := elapsed / float(maxi(cycles[0], 1))
	check(absf(measured - predicted) < predicted * 0.2,
		"a looping board runs at the cycle the preview promised (%.2fs vs %.2fs)" % [measured, predicted])
	var per_cycle := float(whole[0]) / float(maxi(cycles[0] - 1, 1))
	check(absf(per_cycle - float(want_shots)) < 0.5,
		"and fires as many shots as it promised (%.1f vs %d)" % [per_cycle, want_shots])

	# --- loops the flow can never leave ----------------------------------------
	# The board from the report: a trigger feeding a four-part ring that never
	# hands the flow back. Every part of the ring is dead code; nothing outside
	# it is — the INPUT is doing its job, and the stranded OUTPUT is unreached
	# rather than caught.
	var dl := SkillBoard.new(7, 5, "deadloop")
	dl.place("INPUT", Vector2i(0, 2), 0)
	dl.place("DUPLICATE", Vector2i(1, 2), 3)     # in from the west, out north
	dl.place("FIRE", Vector2i(1, 1), 0)          # east
	dl.place("DAMAGE", Vector2i(2, 1), 1)        # south
	dl.place("FIRE", Vector2i(2, 2), 2)          # west, closing the ring
	dl.place("OUTPUT", Vector2i(3, 2), 0)
	var td := dl.trace()
	var caught: Dictionary = td["dead"]
	check(caught.size() == 4, "every part of a ring with no way out is dead code (%d)"
		% caught.size())
	check(not caught.has(Vector2i(0, 2)) and not caught.has(Vector2i(3, 2)),
		"and neither the INPUT feeding it nor the OUTPUT it never reaches is")
	check((td["dead_links"] as Array).size() == 4,
		"the ring's own seams come back with it, so one silhouette can go round it")
	check(dl.first_problem() == Loc.t("editor.problem.dead_loop"),
		"and the board names the trap rather than only saying nothing comes out")

	# The same ring with nothing feeding it: a trap is a trap before anything
	# falls into it, so this is marked too.
	var orphan := SkillBoard.new(7, 5, "orphan")
	orphan.place("DELAY", Vector2i(1, 0), 0)
	orphan.place("DELAY", Vector2i(2, 0), 1)
	orphan.place("DELAY", Vector2i(2, 1), 2)
	orphan.place("DELAY", Vector2i(1, 1), 3)
	check((orphan.trace()["dead"] as Dictionary).size() == 4,
		"a ring with nothing feeding it is dead code all the same")
	check((tr["dead"] as Dictionary).size() == 4, "and so is the one the INPUT feeds")

	# The ring that pays for itself is left alone. Laps through the stat parts
	# and out through a TEE is the pattern charging a skill exists to buy, and
	# calling it dead code would be calling the game dead code.
	check((lp.trace()["dead"] as Dictionary).is_empty(),
		"a ring with a branch out of it is not dead code")
	check((b.trace()["dead"] as Dictionary).is_empty(), "and neither is a plain chain")

	# Nor is a ring whose work is done on the way in rather than at an OUTPUT:
	# trapped or not, it dilates time once a lap for as long as the life lasts.
	var spin := SkillBoard.new(7, 5, "dilate")
	spin.place("INPUT", Vector2i(0, 0), 0)
	spin.place("DELAY", Vector2i(1, 0), 0)
	spin.place("TIME_DILATION", Vector2i(2, 0), 1)
	spin.place("DELAY", Vector2i(2, 1), 2)
	spin.place("DELAY", Vector2i(1, 1), 3)
	check((spin.trace()["dead"] as Dictionary).is_empty(),
		"a ring with TIME DILATION in it is doing something every lap, not nothing")

	# A loop through a trigger's branch queues one follow-up per lap. It used to
	# overwrite a single stored payload instead, so four laps through four
	# DAMAGE parts collapsed into one enormous strike rather than the four
	# separate attacks the board draws.
	var tb := SkillBoard.new(7, 5, "trigger loop")
	tb.place("INPUT", Vector2i(0, 2), 0)
	tb.place("DASHSLASH", Vector2i(1, 2), 0)   # head (1,2), tail (2,2)
	tb.place("ON_HIT", Vector2i(3, 2), 0)      # onward E, branch S
	tb.place("OUTPUT", Vector2i(4, 2), 0)
	tb.place("DAMAGE", Vector2i(3, 3), 1)
	tb.place("DAMAGE", Vector2i(3, 4), 2)
	tb.place("DELAY", Vector2i(2, 4), 2)
	tb.place("DAMAGE", Vector2i(1, 4), 3)
	tb.place("DAMAGE", Vector2i(1, 3), 3)      # back into the DASHSLASH head
	var tr2 := SkillRunner.new(tb)
	tr2.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	tr2.ttl_bonus = 48   # charged, so the branch goes round more than once
	var tsim := tr2.simulate()
	var chain: Array = []
	var link = (tsim["triggers"] as Dictionary).get("ON_HIT", null)
	while link != null:
		chain.append(link)
		link = link.on_hit
	check(chain.size() > 1, "each lap queues its own follow-up (%d)" % chain.size())
	# And the life the pulse carries is the only thing that bounds the chain:
	# the same board charged less queues fewer follow-ups.
	var chain_at := func(bonus: int) -> int:
		var rr := SkillRunner.new(tb)
		rr.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
		rr.ttl_bonus = bonus
		var n := 0
		var l = (rr.simulate()["triggers"] as Dictionary).get("ON_HIT", null)
		while l != null:
			n += 1
			l = l.on_hit
		return n
	var short_chain: int = chain_at.call(12)
	check(short_chain < chain.size(),
		"and life is what bounds it: +12 queues %d, +48 queues %d"
			% [short_chain, chain.size()])
	var rising := true
	for i in range(1, chain.size()):
		if chain[i].damage <= chain[i - 1].damage:
			rising = false
	check(rising, "and each carries only its own lap's damage, not every lap's")
	check(not chain.is_empty() and String(chain[0].form) == "DASHSLASH",
		"the follow-up is the attack the loop runs through")

	# The live runner has to hand out the same chain the preview showed, on the
	# very first attack — the branch that defines it is still walking the board
	# behind that attack, so it has to come from the board, not from history.
	var live: Array = []
	tr2.fired.connect(func(pp: Payload) -> void:
		if live.is_empty():
			var n := 0
			var q = pp.on_hit
			while q != null:
				n += 1
				q = q.on_hit
			live.append(n))
	tr2.set_active(true)
	for i in 400:
		tr2.update(1.0 / 120.0)
	check(not live.is_empty() and int(live[0]) == chain.size(),
		"the first attack already carries the whole chain (%s vs %d)"
			% [str(live), chain.size()])

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
	check(d.first_problem() == Loc.t("editor.problem.side_entry",
			[Components.name_for("AREA"), 1, 1]), "and the message explains it")

	# A flow running into empty space is a leak, not a break.
	var e := SkillBoard.new(7, 5, "leak")
	e.place("INPUT", Vector2i(0, 2), 0)
	var t4 := e.trace()
	check((t4["leaks"] as Array).size() == 1, "a dangling output is reported as a leak")
	check(e.first_problem() == Loc.t("editor.problem.leak",
			[0, 2, Components.dir_name(0)]), "and the message says so")

	# No INPUT at all.
	var f := SkillBoard.new(7, 5, "noinput")
	f.place("SLASH", Vector2i(2, 2), 0)
	check(f.first_problem() == Loc.t("editor.problem.no_input"),
		"a board with no INPUT says so")

	# A wired board with no attack form reports that, not a wiring fault.
	var g := SkillBoard.new(7, 5, "noform")
	g.place("INPUT", Vector2i(0, 2), 0)
	g.place("DELAY", Vector2i(1, 2), 0)
	g.place("OUTPUT", Vector2i(2, 2), 0)
	check(g.first_problem() == Loc.t("editor.problem.no_form"),
		"a formless chain says what is missing")

	print("[TRACE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
