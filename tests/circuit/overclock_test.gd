extends Node
## OVERCLOCK is a trade: a faster clock against a settling delay. The delay is
## real time on purpose — when it was denominated in ticks the speed-up shrank
## it at the same rate it grew, the two cancelled, and stacking did nothing.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[OC] PASS ", what)
	else:
		fails += 1
		push_error("OC FAIL: " + what)

## A row of `n` overclocks feeding a SLASH, off a DELAY on the root, on a
## board exactly as long and one row high — so the row is the middle one, and
## the SLASH stands against the way out.
func build(n: int) -> SkillBoard:
	var b := SkillBoard.new(n + 2, 1, "oc")
	b.set_root("DELAY", Vector2i(0, 0), 0)
	for i in n:
		b.place("OVERCLOCK", Vector2i(1 + i, 0), 0)
	b.place("SLASH", Vector2i(n + 1, 0), 0)
	return b

func cycle(n: int) -> float:
	var b := build(n)
	if int(b.analyze()["overclock"]) != n:
		push_error("OC FAIL: only %d of %d overclocks fitted" % [b.analyze()["overclock"], n])
	var r := SkillRunner.new(b)
	r.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	return float(r.simulate()["cycle_seconds"])

func _ready() -> void:
	var c: Dictionary = {}
	for n in [0, 1, 2, 3, 4, 5, 6, 8, 12, 20, 29]:
		c[n] = cycle(n)
	print("[OC] curve: ", c)

	check(c[1] < c[0] * 0.92, "one overclock visibly shortens the cycle (%.3f -> %.3f)" % [c[0], c[1]])
	check(c[2] < c[1], "a second still helps")
	check(c[1] - c[2] < c[0] - c[1], "but less than the first did — returns diminish")

	var best_n := 0
	for n in c:
		if c[n] < c[best_n]:
			best_n = n
	check(best_n >= 1 and best_n <= 4, "the sweet spot is a handful, not a wall (best = %d)" % best_n)

	# Past the peak it must get steadily worse, with no second dip.
	var monotonic := true
	var prev := -1.0
	for n in [6, 8, 12, 20, 29]:
		if prev >= 0.0 and c[n] <= prev:
			monotonic = false
		prev = c[n]
	check(monotonic, "past the peak, more overclocks are always worse")
	check(c[29] > c[0] * 3.0, "a wall of them is a serious loss (%.3f vs %.3f)" % [c[29], c[0]])
	check(c[8] > c[best_n], "eight is already past the point of profit")

	# Speed is bounded however many are stacked.
	var a29: Dictionary = build(29).analyze()
	check(float(a29["speed_mul"]) < 5.0, "clock speed converges rather than running away")

	# The live runner must actually deliver the cycle the preview promises.
	for n in [0, 2, 8]:
		var b := build(n)
		var r := SkillRunner.new(b)
		r.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
		var predicted := float(r.simulate()["cycle_seconds"])
		var count := [0]
		r.cycle_started.connect(func() -> void: count[0] += 1)
		r.set_active(true)
		var step := 1.0 / 240.0
		var elapsed := 0.0
		var budget: float = maxf(predicted * 6.0, 2.0)
		while elapsed < budget:
			r.update(step)
			elapsed += step
		var measured := elapsed / float(maxi(count[0], 1))
		check(absf(measured - predicted) < predicted * 0.25,
			"live cycle matches the preview at %d overclocks (%.3f vs %.3f)" % [n, measured, predicted])

	print("[OC] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
