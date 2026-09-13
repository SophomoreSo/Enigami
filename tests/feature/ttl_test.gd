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

## A DASHSLASH+ whose ON HIT walks three OVERCLOCKs back round into it, so every
## lap the life pays for is one more follow-up.
func trigger_ring() -> SkillBoard:
	var b := SkillBoard.new(7, 5, "trigger ring")
	b.place("INPUT", Vector2i(0, 2), 0)
	b.place("DASHSLASH_AUTO", Vector2i(1, 2), 0)
	b.place("ON_HIT", Vector2i(3, 2), 0)
	b.place("OUTPUT", Vector2i(4, 2), 0)
	b.place("OVERCLOCK", Vector2i(3, 3), 2)
	b.place("OVERCLOCK", Vector2i(2, 3), 2)
	b.place("OVERCLOCK", Vector2i(1, 3), 3)
	return b

## Attacks in a chain: the one fired, and every follow-up hung off it.
func links(p) -> int:
	var n := 0
	while p != null:
		n += 1
		p = p.on_hit
	return n

## One live cast at `bonus`, run to the end: how many attacks its chain holds.
func live_links(r: SkillRunner, bonus: int) -> int:
	r.ttl_bonus = bonus
	var got := [0]
	var count := func(p: Payload) -> void: got[0] = links(p)
	r.fired.connect(count)
	r.set_active(true)
	r.update(1.0 / 60.0)
	r.set_active(false)
	for i in 6000:
		if r.is_ready():
			break
		r.update(1.0 / 60.0)
	r.fired.disconnect(count)
	return got[0]

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

	# What a charge buys has to ride on the cast that paid for it. A trigger
	# branch walks behind the attack that carries it, and each cast used to carry
	# the chain the cast before it had built: a charged cast after a tap went out
	# with no follow-ups, and every tap after a charged cast kept its whole chain.
	var tr := runner(trigger_ring())
	var want := {}
	for bonus in [0, 16, SkillRunner.MAX_TTL_BONUS]:
		tr.ttl_bonus = bonus
		want[bonus] = links(tr.simulate()["triggers"].get("ON_HIT", null)) + 1
	check(want[SkillRunner.MAX_TTL_BONUS] > want[16] and want[16] > want[0],
		"charging a looping trigger buys follow-ups (%s)" % str(want))
	var got: Array = []
	var expected: Array = []
	for bonus in [0, SkillRunner.MAX_TTL_BONUS, SkillRunner.MAX_TTL_BONUS, 16, 0]:
		got.append(live_links(tr, bonus))
		expected.append(want[bonus])
	check(got == expected,
		"each live cast carries the chain its own charge built (%s, want %s)" % [str(got), str(expected)])

	print("[TTL] ---- %d failures ----" % fails)
	get_tree().quit()
