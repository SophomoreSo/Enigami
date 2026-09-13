extends Node
## Every pulse carries a time to live — how many more parts it may enter — which
## is what stops a cycle in the board looping forever. Charging buys more of it.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[TTL] PASS ", what)
	else:
		fails += 1
		push_error("TTL FAIL: " + what)

func runner(b: SkillBoard, bonus: int = 0) -> SkillRunner:
	var r := SkillRunner.new(b)
	r.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	r.ttl_bonus = bonus
	return r

## A ring that tees out to an attack on every lap.
func ring() -> SkillBoard:
	var b := SkillBoard.new(7, 5, "ring")
	b.place("INPUT", Vector2i(0, 1), 0)
	b.place("WIRE", Vector2i(1, 1), 3)
	b.place("WIRE", Vector2i(1, 0), 0)
	b.place("WIRE", Vector2i(2, 0), 0)
	b.place("WIRE", Vector2i(3, 0), 1)
	b.place("WIRE", Vector2i(3, 1), 2)
	b.place("TEE", Vector2i(2, 1), 1)
	b.place("SLASH", Vector2i(2, 2), 0)
	b.place("OUTPUT", Vector2i(3, 2), 0)
	return b

## A straight run of `n` wires into an attack: no cycle, just length.
func chain(n: int) -> SkillBoard:
	var b := SkillBoard.new(60, 5, "chain")
	b.place("INPUT", Vector2i(0, 2), 0)
	for i in n:
		b.place("WIRE", Vector2i(1 + i, 2), 0)
	b.place("SLASH", Vector2i(1 + n, 2), 0)
	b.place("OUTPUT", Vector2i(2 + n, 2), 0)
	return b

func shots(r: SkillRunner) -> int:
	return (r.simulate()["outputs"] as Array).size()

func _ready() -> void:
	# A cycle has to end in the live runner, not just on paper — and still end
	# when it has been charged as far as charge goes.
	var live := runner(ring(), SkillRunner.MAX_TTL_BONUS)
	live.set_active(true)
	var ran := false
	var ended := false
	for i in 6000:
		live.update(1.0 / 60.0)
		if not live.pulses.is_empty():
			ran = true
		elif ran and live.cooldown > 0:
			ended = true
			break
	check(ran, "a fully charged ring runs")
	check(ended, "and comes to a stop rather than circling forever")

	# More life, more laps, monotonically.
	var last := 0
	var rising := true
	for bonus in [0, 12, 24, 48]:
		var n := shots(runner(ring(), bonus))
		if n <= last:
			rising = false
		last = n
	check(rising, "more life buys strictly more laps (up to %d shots)" % last)

	# Length alone must never cost a board its shot: a cast's life starts at
	# exactly one pass of whatever board it is, short or long.
	for n in [2, 12, 40]:
		var r := runner(chain(n))
		check(r.pass_cost == n + 3,
			"a %d-wire chain costs %d to walk once (%d)" % [n, n + 3, r.pass_cost])
		check(shots(r) == 1, "and one pass is exactly what an uncharged cast takes")

	# Charge buys life, and life is only ever spent going round. A board with no
	# cycle in it walks to its OUTPUT and stops there however much it is given,
	# so charging must never turn one cast into several.
	for bonus in [0, 12, 24, SkillRunner.MAX_TTL_BONUS]:
		check(shots(runner(chain(3), bonus)) == 1,
			"a cycle-free board fires once at +%d charge" % bonus)
	check(shots(runner(Weapons.make_innate_board("SWORD"), SkillRunner.MAX_TTL_BONUS)) == 1,
		"and so does a fully charged starter board")

	print("[TTL] ---- %d failures ----" % fails)
	get_tree().quit()
