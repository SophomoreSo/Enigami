extends Node
## The Bomber: a monster whose attack is the last thing it does. Its board is a
## HEADBUTT carrying DAMAGE, FIRE and an EXPLODE; it runs at whoever it hunts,
## headbutts them once it is close, and goes up where it stands — the same flow
## with no form under it, which its EXPLODE makes a burst of its own — dying in
## it, whether the blow found anybody or not (`Enemy._go_up`). Killed before it
## gets there, it just dies.
##
## Headless: nothing here is looked at, only what each of them took.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[BOMBER] PASS ", what)
	else:
		fails += 1
		push_error("BOMBER FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Until every burst in the air has opened all the way and gone, at whatever
## pace the frames come: a burst's hits land as its edge passes them.
func bursts_done() -> void:
	for i in 1000:
		var open := false
		for c in get_children():
			if c is AreaBurst:
				open = true
		if not open:
			return
		await frames(1)

## A dummy that stands still and takes damage, at `at`, on `team`: 0 is the
## player's side, which the Bomber hunts, and 1 its own.
func dummy(at: Vector2, team: int) -> Actor:
	var a := Actor.new()
	a.team = team
	a.max_health = 500.0
	add_child(a)
	a.global_position = at
	return a

## A Bomber at `at`, hunting `target`.
func bomber(at: Vector2, target: Actor) -> Enemy:
	var e := Enemy.new()
	e.setup("BOMBER", 1, "")
	add_child(e)
	e.global_position = at
	e.target = target
	return e

## What one of its attacks carries: the flow its own board resolves to.
func blow(e: Enemy) -> Payload:
	var outs: Array = e.runner.simulate()["outputs"]
	return (outs[0] as Payload).clone() if outs.size() == 1 else null

func _ready() -> void:
	# Arena.register wants a node to hang the attacks and Deferred nodes off.
	Arena.register(self)
	await frames(2)
	_the_board()
	await _goes_up()
	await _goes_up_missing()
	await _killed_first()
	print("[BOMBER] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## Its own board: a headbutt, as hard as a DAMAGE makes it, burning, bursting
## what it strikes — and a monster like the rest, which raids bring and which
## drops what it was made of.
func _the_board() -> void:
	var def := Monsters.get_def("BOMBER")
	check(String(def.get("board", "")) == "bomber" and bool(def.get("spent_by_attack", false))
			and String(def["ai"]) == "runner",
		"the Bomber runs at what it hunts, on a board of its own, and is spent by its attack")
	check(Monsters.NORMAL_POOL.has("BOMBER"), "and raids bring it")
	var drops := Monsters.drop_pool("BOMBER")
	var made: Array = []
	for id in ["HEADBUTT", "DAMAGE", "FIRE", "EXPLODE"]:
		if drops.has(id):
			made.append(id)
	check(made.size() == 4 and drops.size() == 4, "its board is a HEADBUTT, a DAMAGE, a FIRE and an EXPLODE (%s)" % str(drops))
	var e := Enemy.new()
	e.setup("BOMBER", 1, "")
	add_child(e)
	var base := (e.runner.base_payload_provider.call() as Payload).damage
	var p := blow(e)
	check(p != null and p.form == "HEADBUTT" and p.explode == 1 and p.has_element("FIRE") and p.damage > base,
		"which make one burning headbutt that bursts, harder than the monster's own blow (%s)"
			% (Attacks.summary(p) if p != null else "nothing"))
	e.queue_free()

## Close enough, it headbutts whoever it hunts, and goes up: the one struck
## takes the blow and then the blast, anyone beside them is caught as well, and
## nothing on its own side is. And it is dead.
func _goes_up() -> void:
	var victim := dummy(Vector2(1030, 0), 0)
	var beside := dummy(Vector2(1080, 0), 0)
	var kin := dummy(Vector2(970, 0), 1)
	var e := bomber(Vector2(1000, 0), victim)
	var p := blow(e)
	var hp_victim := victim.health
	var hp_beside := beside.health
	var hp_kin := kin.health
	e._on_fired(p)
	check(e.dead, "the attack is the last thing it does")
	await bursts_done()
	check(hp_victim - victim.health >= p.damage * 2.0 - 0.01,
		"the one it struck takes the headbutt and then the blast it goes up in (%.1f, two of %.1f)"
			% [hp_victim - victim.health, p.damage])
	check(hp_beside - beside.health >= p.damage - 0.01,
		"anyone beside them is caught as well (%.1f)" % (hp_beside - beside.health))
	check(is_equal_approx(kin.health, hp_kin), "and nothing on its own side is")

## A blow that finds nobody — whoever it hunts out of its reach — still ends it:
## it goes up where the lunge left it, and catches whoever is near.
func _goes_up_missing() -> void:
	var far := dummy(Vector2(2300, 0), 0)
	var near := dummy(Vector2(1970, 0), 0)
	var e := bomber(Vector2(2000, 0), far)
	var p := blow(e)
	var hp_far := far.health
	var hp_near := near.health
	e._on_fired(p)
	check(e.dead, "a blow that finds nobody ends it all the same")
	await bursts_done()
	check(is_equal_approx(far.health, hp_far), "and what it was after, out of reach, is untouched")
	check(hp_near - near.health >= p.damage - 0.01,
		"but what stood near it is caught in the blast (%.1f)" % (hp_near - near.health))

## Killed before it gets there, it does not go up: only its attack spends it.
func _killed_first() -> void:
	var near := dummy(Vector2(3030, 0), 0)
	var e := bomber(Vector2(3000, 0), near)
	var hp_near := near.health
	e.apply_damage(9999.0)
	check(e.dead, "a Bomber can be killed before it gets there")
	await frames(3)
	await bursts_done()
	check(is_equal_approx(near.health, hp_near), "and then it goes up in nothing")
