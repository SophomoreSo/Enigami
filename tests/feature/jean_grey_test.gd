extends Node2D
## The Jean Grey test has to be what it says: a diamond in a guarded building, a
## pit nobody can see into to wait in, and a way to the diamond through the
## guards one after another — the rock's graph putting the player's hands into
## each — that a player can actually take. The theft is done only when the
## player's own body has the diamond back in the pit, and the ground sets
## itself again after a theft, after a fall, and on R.
##
## The way through is played, not asserted: the computer's hands wait in the
## pit for the gate guard to look away, throw the rock into its back, walk it in
## as one of them, throw on into the guard that flies, fly the diamond out to
## the body and carry it home.

var fails := 0
var screen: JeanGreyTest
var hands: ComputerHands
var stolen := 0
var fell := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[JEAN] PASS ", what)
	else:
		fails += 1
		push_error("JEAN FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()

## Waits until `cond` holds, for at most `secs`. Whether it did.
func until(cond: Callable, secs: float) -> bool:
	var t := 0.0
	while t < secs:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return cond.call()

func guards() -> Array:
	return screen.room.get_children().filter(func(c: Node) -> bool: return c is Enemy and not c.dead)

func guard(kind: String) -> Enemy:
	for e in guards():
		if e.kind == kind:
			return e
	return null

func rock() -> LooseRock:
	for c in screen.room.get_children():
		if c is LooseRock and not c.is_queued_for_deletion():
			return c
	return null

## The computer's hands on the body there is now: a reset makes a new one.
func take_hands() -> void:
	hands = ComputerHands.new()
	screen.player.input.add(hands)

## Walks whatever the player is in over to `x`, sprinting. Whether it got there.
func walk_to(x: float, secs: float = 6.0) -> bool:
	var t := 0.0
	hands.sprint = true
	while t < secs:
		var dx := x - screen.player.vessel().global_position.x
		if absf(dx) < 6.0:
			break
		hands.move = signf(dx)
		await get_tree().process_frame
		t += get_process_delta_time()
	hands.move = 0.0
	hands.sprint = false
	return t < secs

## Flies the monster the player is in to within `near` of `to`, flapping while
## it is below it.
func fly_to(to: Vector2, near: float, secs: float = 5.0) -> bool:
	var t := 0.0
	var flap := 0.0
	hands.sprint = true
	while t < secs:
		var d := to - screen.player.vessel().global_position
		if d.length() < near:
			break
		hands.move = signf(d.x) if absf(d.x) > 4.0 else 0.0
		flap -= get_process_delta_time()
		if d.y < -4.0 and flap <= 0.0:
			hands.jump()
			flap = 0.22
		await get_tree().process_frame
		t += get_process_delta_time()
	hands.move = 0.0
	hands.sprint = false
	return t < secs

## One throw of the rock's graph at `at`.
func throw_at(at: Vector2) -> void:
	hands.point_at(at)
	await frames(3)
	hands.attack = true
	await frames(2)
	hands.attack = false

func _ready() -> void:
	seed(20261003)
	screen = JeanGreyTest.new()
	screen.stolen.connect(func(_s: float) -> void: stolen += 1)
	screen.fell.connect(func() -> void: fell += 1)
	add_child(screen)
	await frames(20)
	_ground()
	_board()
	await _the_theft()
	await _whose_hands()
	await _the_body_falls()
	await _setting_it_again()
	print("[JEAN] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- the ground ---------------------------------------------------------------
func _ground() -> void:
	var room := screen.room
	var rows_ok := JeanGreyBase.LAYOUT.size() == Room.H
	for row in JeanGreyBase.LAYOUT:
		rows_ok = rows_ok and String(row).length() == Room.W
	check(rows_ok, "the ground is %d rows of %d cells" % [Room.H, Room.W])

	var posts := 0
	var facing_ok := true
	for mark in JeanGreyBase.POSTS:
		posts += room.cells_marked(String(mark)).size()
	for e in guards():
		var rec: Dictionary = e.get_meta("record")
		facing_ok = facing_ok and e.facing == int(rec["facing"])
	check(screen.total_guards == posts and guards().size() == posts,
		"a guard on every post (%d of %d)" % [guards().size(), posts])
	check(facing_ok, "each looking the way its post says")
	var grounded := true
	for e in guards():
		grounded = grounded and (e.is_on_floor() if e.ai() != "flyer" else not e.is_on_floor())
	check(grounded, "the ones that walk stand on a floor, and the one that flies holds its post in the air")

	# The pit is the one place to wait: nobody can see down into it.
	var seen: Array = []
	for c in room.cells_marked(",") + room.cells_marked("P"):
		var at := room.stand_point(c, Player.BODY.y * 0.5)
		for e in guards():
			if room.has_line_of_sight(e.global_position, at):
				seen.append("%s from %s" % [c, e.kind])
	check(seen.is_empty(), "no guard can see into the pit (%s)" % str(seen))
	check(room.in_start(screen.player.global_position), "and the player starts in it")

	# Behind the gate guard, nothing inside can see the body: only the gate
	# guard can give it away, and only by looking round.
	var g1 := guard("CRAWLER")
	var behind := Vector2(g1.global_position.x - 96.0, g1.global_position.y)
	var inside: Array = []
	for e in guards():
		if e != g1 and room.has_line_of_sight(e.global_position, behind) \
				and e.global_position.distance_to(behind) <= float(e.def["aggro"]):
			inside.append(e.kind)
	check(inside.is_empty(), "behind the gate guard, nobody inside can see the body (%s)" % str(inside))

	# The diamond is out of any jump: only something that flies gets to it.
	var gem := screen.diamond
	var floor_y := float(18 * Room.CELL)
	var lifted := floor_y - (gem.global_position.y + Diamond.RADIUS)
	var body_reach := (pow(Player.JUMP_VELOCITY, 2.0) + pow(Player.DOUBLE_JUMP_VELOCITY, 2.0)) \
		/ (2.0 * Player.GRAVITY)
	var monster_reach := pow(Enemy.PILOTED_JUMP, 2.0) / (2.0 * Enemy.GRAVITY)
	check(lifted > body_reach + Player.BODY.y and lifted > monster_reach + 40.0,
		"the diamond lies %.0f px over the hall floor, past a double jump (%.0f) and a monster's (%.0f)"
			% [lifted, body_reach, monster_reach])
	check(gem.carrier == null and gem.global_position.distance_to(room.diamond_point()) < 1.0,
		"and lies on its ledge in nobody's hands")

## --- the rock's graph ---------------------------------------------------------
func _board() -> void:
	var r := SkillRunner.new(screen.board)
	r.base_payload_provider = func() -> Payload: return Weapons.base_payload(JeanGreyTest.WEAPON)
	var outs: Array = r.simulate()["outputs"]
	var p: Payload = outs[0] if outs.size() == 1 else null
	check(p != null and p.form == "PROJECTILE" and is_equal_approx(p.possess, 10.0),
		"the rock's graph throws it carrying POSSESS twice, ten seconds (%s)"
			% (Attacks.summary(p) if p != null else "nothing"))
	check(screen.player.weapon_id == "ROCK" and screen.player.holds("ROCK"),
		"and the player starts with the rock in hand")

## --- one way through, played --------------------------------------------------
func _the_theft() -> void:
	take_hands()
	var p := screen.player
	var g1 := guard("CRAWLER")
	var flyer := guard("DRIFTER")
	var gem := screen.diamond

	# Waiting in the pit for the gate guard to look the other way.
	check(await until(func() -> bool: return g1.facing == 1, Enemy.GLANCE_MAX + 0.5),
		"the gate guard looks over its shoulder while the player waits")
	hands.jump()
	await walk_to(g1.global_position.x - 96.0)
	check(screen.alerted() == 0, "out of the pit and up behind it, unseen")
	await throw_at(g1.global_position + Vector2(0, -40))
	check(await until(func() -> bool: return p.possessing == g1, 1.5),
		"the rock in its back puts the player's hands into it")

	# As one of them, the rock back in hand, and in through the gate.
	check(await until(func() -> bool: return rock() != null and rock().resting, 2.0), "the rock comes down by it")
	await walk_to(rock().global_position.x)
	check(await until(func() -> bool: return p.holds("ROCK") and p.weapon_hands() == g1, 1.0),
		"and the gate guard picks it back up")
	await walk_to(flyer.global_position.x - 8.0)
	check(p.possessing == g1 and screen.alerted() == 0,
		"walked in through the gate and down the hall as one of them (%.1fs left)" % p.possess_left)
	await throw_at(flyer.global_position + Vector2(0, -10))
	check(await until(func() -> bool: return p.possessing == flyer, 1.5),
		"thrown up into the one that flies, the hands go on into it")

	# Up to the ledge, and out with the diamond.
	await fly_to(Vector2(flyer.global_position.x, gem.global_position.y - 40.0), 16.0)
	await fly_to(gem.global_position + Vector2(0, -8), 6.0)
	check(await until(func() -> bool: return gem.carrier == flyer, 1.0), "it takes the diamond off the ledge")
	await fly_to(Vector2(20 * Room.CELL, 8 * Room.CELL), 24.0)
	await fly_to(Vector2(17 * Room.CELL, 16 * Room.CELL + 20), 20.0)
	await fly_to(Vector2(12 * Room.CELL, 16 * Room.CELL + 20), 20.0)
	await fly_to(p.global_position + Vector2(40, -20), 24.0)
	check(p.possessing == flyer and gem.carrier == flyer,
		"and carries it out of the gate to the body (%.1fs left)" % p.possess_left)
	check(not screen.over, "which is not a theft yet: it is not in the player's own hands")

	# Out of the monster: the diamond falls where it was, and the body takes it.
	hands.step_out()
	check(await until(func() -> bool: return gem.carrier == null and gem._down > Diamond.SETTLE, 2.0),
		"stepping out lets go of it, and it comes down on the floor")
	await walk_to(gem.global_position.x)
	check(await until(func() -> bool: return gem.carried_by_player(), 1.0), "the body picks it up")
	await walk_to(3.0 * Room.CELL)
	check(await until(func() -> bool: return stolen == 1, 1.0) and screen.over,
		"and carried back into the pit, it is stolen (%.1fs)" % screen.best)
	check(screen.best > 0.0, "and the time is kept")

	await wait(JeanGreyTest.RESET_DELAY + 0.3)
	check(not screen.over and guards().size() == screen.total_guards,
		"then the ground sets itself again (%d guards)" % guards().size())
	check(gem.carrier == null and gem.global_position.distance_to(screen.room.diamond_point()) < 1.0,
		"with the diamond back on its ledge")

## --- whose hands ----------------------------------------------------------------
func _whose_hands() -> void:
	var p := screen.player
	var gem := screen.diamond
	var warden := guard("WARDEN")
	var crawler := guard("CRAWLER")
	var flyer := guard("DRIFTER")

	# A monster with its own mind leaves it where it is.
	gem.place(warden.global_position + Vector2(0, warden.body_size.y * 0.5 - Diamond.RADIUS))
	await wait(0.6)
	check(gem.carrier == null, "a guard with its own mind never picks the diamond up")

	# One the player is in does, and hopping on lets go of it.
	p.possess(crawler, 5.0)
	gem.place(crawler.global_position)
	check(await until(func() -> bool: return gem.carrier == crawler, 1.0), "a guard the player is in takes it")
	var was := crawler.global_position
	p.possess(flyer, 5.0)
	await frames(2)
	check(gem.carrier == null and gem.global_position.distance_to(was) < Room.CELL,
		"hopping on to the next lets go of it where the last one stood")

	# Let go of in the air, it falls to the floor under it.
	await until(func() -> bool: return gem._down > Diamond.SETTLE, 2.0)
	gem.place(flyer.global_position)
	check(await until(func() -> bool: return gem.carrier == flyer, 1.0), "the one that flies takes it")
	var over := flyer.global_position.x
	p.release()
	await until(func() -> bool: return gem._down > Diamond.SETTLE, 3.0)
	var cell := Vector2i(int(gem.global_position.x / Room.CELL), int((gem.global_position.y + Diamond.RADIUS + 1.0) / Room.CELL))
	check(screen.room.is_solid(cell.x, cell.y) and absf(gem.global_position.x - over) < 1.0,
		"and let go of in the air, it falls straight to the floor under it")
	screen.reset_floor()
	await frames(4)

## --- the body falls -------------------------------------------------------------
func _the_body_falls() -> void:
	var p := screen.player
	p.apply_damage(99999.0)
	await frames(2)
	check(fell == 1 and screen.over, "the body falling ends the attempt")
	await wait(JeanGreyTest.RESET_DELAY + 0.3)
	check(is_instance_valid(screen.player) and not screen.player.dead and not screen.over
			and screen.room.in_start(screen.player.global_position),
		"and a new one is in the pit a moment later")
	check(stolen == 1, "a fall is not a theft")

## --- R --------------------------------------------------------------------------
func _setting_it_again() -> void:
	take_hands()
	var p := screen.player
	var crawler := guard("CRAWLER")
	# The rock thrown away, a guard taken, the diamond moved.
	await throw_at(p.global_position + Vector2(300, -60))
	await until(func() -> bool: return rock() != null, 2.0)
	p.possess(crawler, 5.0)
	screen.diamond.place(crawler.global_position)
	await frames(4)
	screen.reset_floor()
	await frames(4)
	var np := screen.player
	check(np != p and np.holds("ROCK") and np.vessel() == np, "R hands back a body with the rock in hand")
	check(rock() == null, "and the rock that was lying out is gone")
	check(guards().size() == screen.total_guards and screen.alerted() == 0,
		"every guard at its post, none of them after anyone")
	check(screen.diamond.carrier == null
			and screen.diamond.global_position.distance_to(screen.room.diamond_point()) < 1.0,
		"and the diamond back on its ledge")
