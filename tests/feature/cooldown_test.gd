extends Node
## The numbers behind the slot's cooldown wipe: one continuous 0 → 1 fill across
## the whole wait, measured against how long a cycle really takes, and a flash
## at the moment it lands.

const DT := 1.0 / 60.0

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[CD] PASS ", what)
	else:
		fails += 1
		push_error("CD FAIL: " + what)

func make(weapon: String) -> SkillRunner:
	var r := SkillRunner.new(Weapons.make_innate_board(weapon))
	r.base_payload_provider = func() -> Payload: return Weapons.base_payload(weapon)
	return r

## Runs one whole cast at `bonus` charge, and reports how long it took and what
## the wipe read on the last frame before the slot came free.
func cast_at(r: SkillRunner, bonus: int) -> Dictionary:
	r.ttl_bonus = bonus
	r.set_active(true)
	var ran := false
	var wipe := 0.0
	var secs := 0.0
	for i in 2000:
		r.update(DT)
		if not r.is_ready():
			ran = true
			wipe = r.ready_ratio()
			secs += DT
			r.set_active(false)   # one cast, not a held repeat
		elif ran:
			break
	return {"wipe": wipe, "seconds": secs}

## A straight board: INPUT, the listed parts in a row, then OUTPUT. Returns how
## many ticks one whole cycle of it takes.
func ticks_of(ids: Array) -> int:
	var b := SkillBoard.new(12, 5, "chain")
	b.place("INPUT", Vector2i(0, 2), 0)
	var x := 1
	for id in ids:
		b.place(String(id), Vector2i(x, 2), 0)
		x += int(Components.get_def(id)["cells"])
	b.place("OUTPUT", Vector2i(x, 2), 0)
	var r := SkillRunner.new(b)
	r.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	return int(r.simulate()["ticks"])

func _ready() -> void:
	# Held: the fill runs the whole wait and restarts, and each landing flashes.
	var r := make("SWORD")
	var predicted := float(r.simulate()["cycle_seconds"])
	r.set_active(true)
	var samples: Array = []
	var flashes := 0
	var was_flash := 0.0
	var backwards := 0
	var last := 0.0
	for i in 200:
		r.update(DT)
		var p := r.ready_ratio()
		if r.ready_flash > was_flash:
			flashes += 1
		was_flash = r.ready_flash
		if p < last - 0.001 and p > 0.02:
			backwards += 1
		last = p
		samples.append(p)
	check(samples.max() > 0.85, "the fill reaches the bottom of the card (%.2f)" % samples.max())
	check(backwards == 0, "and only ever runs downward, never jumping back (%d reversals)" % backwards)
	check(flashes >= 2, "a held skill flashes on every landing (%d in %.1fs)" % [flashes, 200 * DT])
	check(absf(r.cycle_seconds - predicted) < predicted * 0.2,
		"the fill is measured against the real cycle (%.3fs vs %.3fs preview)"
			% [r.cycle_seconds, predicted])

	# Released: it comes back, flashes, and then sits ready.
	var q := make("SWORD")
	q.set_active(true)
	for i in 4:
		q.update(DT)
	q.set_active(false)
	var peak := 0.0
	for i in 60:
		q.update(DT)
		peak = maxf(peak, q.ready_flash)
	check(q.is_ready(), "a released skill settles as ready")
	check(is_equal_approx(q.ready_ratio(), 1.0), "with the card fully clear (%.2f)" % q.ready_ratio())
	check(peak > 0.9, "and it flashed when it got there (%.2f)" % peak)
	for i in 60:
		q.update(DT)
	check(q.ready_flash <= 0.0, "the flash fades out rather than sticking on")

	# A slower board must take proportionally longer to fill.
	var slow := make("ROCK")
	var slow_cycle := float(slow.simulate()["cycle_seconds"])
	check(slow_cycle > predicted,
		"the ROCK board really is the slower one (%.2fs vs %.2fs)" % [slow_cycle, predicted])
	slow.set_active(true)
	for i in 200:
		slow.update(DT)
	check(slow.cycle_seconds > r.cycle_seconds,
		"and its slot fills more slowly to match (%.3fs vs %.3fs)"
			% [slow.cycle_seconds, r.cycle_seconds])

	# Charging changes how long a cast takes, so one cycle stopped predicting the
	# next one the moment holding the button bought laps. The wipe has to fill
	# against the cast actually running: a charged cast followed by an uncharged
	# one had the slot reading four tenths full at the instant it was castable.
	var ring := SkillBoard.new(7, 5, "ring")
	ring.place("INPUT", Vector2i(0, 1), 0)
	ring.place("WIRE", Vector2i(1, 1), 3)
	ring.place("WIRE", Vector2i(1, 0), 0)
	ring.place("WIRE", Vector2i(2, 0), 0)
	ring.place("WIRE", Vector2i(3, 0), 1)
	ring.place("WIRE", Vector2i(3, 1), 2)
	ring.place("TEE", Vector2i(2, 1), 1)
	ring.place("SLASH", Vector2i(2, 2), 0)
	ring.place("OUTPUT", Vector2i(3, 2), 0)
	var lr := SkillRunner.new(ring)
	lr.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	var charged := cast_at(lr, SkillRunner.MAX_TTL_BONUS)
	var plain := cast_at(lr, 0)
	check(charged["seconds"] > plain["seconds"] * 1.5,
		"a charged cast really is the longer one (%.2fs vs %.2fs)"
			% [charged["seconds"], plain["seconds"]])
	# Alternating is what catches it: each cast is measured against the last.
	var worst := 1.0
	for bonus in [SkillRunner.MAX_TTL_BONUS, 0, SkillRunner.MAX_TTL_BONUS, 0]:
		worst = minf(worst, float(cast_at(lr, bonus)["wipe"]))
	check(worst > 0.9,
		"the wipe is full when the slot comes free, charged or not (worst %.2f)" % worst)

	# One tick per cell. What a part costs is the room it takes up, so a cycle can
	# be counted off the grid instead of looked up part by part.
	var drift: Array = []
	for id in Components.DEFS:
		if Components.tick_cost(id) != int(Components.get_def(id)["cells"]):
			drift.append(id)
	check(drift.is_empty(), "every part costs one tick per cell (%s)" % str(drift))
	check(Components.tick_cost("AREA") == 2 and Components.tick_cost("WIRE") == 1,
		"a two-cell part costs two ticks and a one-cell part one")
	# And the board agrees: every cell added to the path is one more tick,
	# whichever part it belongs to. DELAY, which used to hold a flow for twelve
	# ticks of its own, is now a cell like any other.
	var one := ticks_of(["WIRE"])
	check(ticks_of(["WIRE", "WIRE"]) - one == 1,
		"a second WIRE costs one tick (%d)" % (ticks_of(["WIRE", "WIRE"]) - one))
	check(ticks_of(["WIRE", "DELAY"]) - one == 1,
		"and so does a DELAY (%d)" % (ticks_of(["WIRE", "DELAY"]) - one))

	print("[CD] ---- %d failures ----" % fails)
	get_tree().quit()
