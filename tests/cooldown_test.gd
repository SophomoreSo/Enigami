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

	print("[CD] ---- %d failures ----" % fails)
	get_tree().quit()
