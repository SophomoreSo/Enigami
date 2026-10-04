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

## The guard of `kind` nearest column `col`.
func nearest(kind: String, col: int) -> Enemy:
	var best: Enemy = null
	for e in guards():
		if e.kind == kind and (best == null or absf(e.global_position.x - (col + 0.5) * Room.CELL)
				< absf(best.global_position.x - (col + 0.5) * Room.CELL)):
			best = e
	return best

func gunman_near(col: int) -> Enemy:
	return nearest("GUNMAN", col)

func crawler_near(col: int) -> Enemy:
	return nearest("CRAWLER", col)

## The Crawler in front of the gate: the nearest to the pit.
func gate_guard() -> Enemy:
	return nearest("CRAWLER", 0)

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
func walk_to(x: float, secs: float = 10.0) -> bool:
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

## One throw of the rock's graph at `at`. How long the player had left in the
## monster they threw from is kept, for saying how close it was.
var last_left := 0.0

func throw_at(at: Vector2) -> void:
	last_left = screen.player.possess_left
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
	await _shot_down()
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
		rows_ok = rows_ok and String(row).length() == room.cols
	check(rows_ok and room.rows == Room.H, "the ground is %d rows high, every one as long" % Room.H)
	check(room.cols * Room.CELL >= 3 * Room.W * Room.CELL,
		"and three screens across (%d cells)" % room.cols)

	var posts := 0
	var facing_ok := true
	for mark in JeanGreyBase.POSTS:
		posts += room.cells_marked(String(mark)).size()
	for e in guards():
		var rec: Dictionary = e.get_meta("record")
		facing_ok = facing_ok and e.facing == int(rec["facing"])
	check(screen.total_guards == posts and guards().size() == posts,
		"a guard on every post (%d of %d)" % [guards().size(), posts])
	check(guards().filter(func(e: Enemy) -> bool: return e.kind == "GUNMAN").size() >= 3,
		"Gunmen among them")
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

	# Behind the gate guard, nothing else notices the body: only the gate guard
	# can give it away, and only by looking round.
	var g1 := gate_guard()
	var behind := Vector2(g1.global_position.x - 96.0, g1.global_position.y)
	var others: Array = []
	for e in guards():
		if e != g1 and room.has_line_of_sight(e.global_position, behind) \
				and e.global_position.distance_to(behind) <= float(e.def["aggro"]):
			others.append(e.kind)
	check(others.is_empty(), "behind the gate guard, nobody else can see the body (%s)" % str(others))

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

## --- the rock's graph, and the Gunman's ------------------------------------------
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
	check(is_equal_approx(screen.player.max_health, JeanGreyTest.BODY_HEALTH),
		"the body has %.0f, whatever the profile has built" % JeanGreyTest.BODY_HEALTH)

	var gun := gunman_near(36)
	var shot: Payload = gun.runner.simulate()["outputs"][0]
	check(shot.damage * 2.0 < JeanGreyTest.BODY_HEALTH and shot.damage * 3.0 >= JeanGreyTest.BODY_HEALTH,
		"a Gunman's shot (%.0f) takes three to put the body down, two after anything else" % shot.damage)
	check(not Monsters.NORMAL_POOL.has("GUNMAN") and Monsters.get_def("GUNMAN")["ai"] == "turret",
		"and a Gunman holds its post, and is never met in a raid")

## Stood in the gate in front of the Gunman watching it, the body takes three
## shots.
func _shot_down() -> void:
	var p := screen.player
	var gun := gunman_near(36)
	var hits := [0]
	p.damaged.connect(func(_a: Actor, _n: float) -> void: hits[0] += 1)
	p.global_position = Vector2(gun.global_position.x - 6.0 * Room.CELL, 18 * Room.CELL - Player.BODY.y * 0.5)
	gun.face(-1)
	check(await until(func() -> bool: return fell == 1, 8.0),
		"the body stood in front of a Gunman is shot down")
	check(hits[0] == 3, "by its third shot (%d)" % hits[0])
	await wait(JeanGreyTest.RESET_DELAY + 0.3)
	fell = 0

## --- one way through, played --------------------------------------------------
## Throws the rock from the monster the player is in, `back` px to the side of
## `target`, into it. Whether the hands went in.
func hop(target: Enemy, back: float, aim_up: float = 40.0) -> bool:
	var p := screen.player
	await walk_to(target.global_position.x + back)
	await throw_at(target.global_position + Vector2(0, -aim_up))
	return await until(func() -> bool: return p.possessing == target, 1.5)

## Walks the monster the player is in over the rock where it came down.
func fetch_rock() -> bool:
	var p := screen.player
	if not await until(func() -> bool: return rock() != null and rock().resting, 2.0):
		return false
	await walk_to(rock().global_position.x)
	return await until(func() -> bool: return p.holds("ROCK") and p.weapon_hands() == p.vessel(), 1.0)

## And over the diamond.
func fetch_diamond() -> bool:
	var gem := screen.diamond
	var p := screen.player
	await until(func() -> bool: return gem.carrier == null and gem._down >= Diamond.SETTLE, 2.0)
	await walk_to(gem.global_position.x)
	return await until(func() -> bool: return gem.carrier == p.vessel(), 1.0)

func _the_theft() -> void:
	take_hands()
	var p := screen.player
	var g1 := gate_guard()
	var g2 := crawler_near(52)
	var flyer := guard("DRIFTER")
	var gm2 := gunman_near(80)
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

	# In through the gate as one of them, past the Gunman watching it, and into
	# the Crawler down the hall.
	check(await fetch_rock(), "the gate guard picks the rock back up")
	check(await hop(g2, -96.0), "and throws it into the Crawler in the first hall (%.1fs were left)" % last_left)

	# Down the vault hall to the Drifter, and up into it under the Gunman's
	# eyes: a throw that lands POSSESS hurts none of them that is left to tell.
	check(await fetch_rock(), "the Crawler picks it up")
	await walk_to(flyer.global_position.x - 8.0)
	check(p.possessing == g2, "and walks it under the Drifter as one of them (%.1fs left)" % p.possess_left)
	await throw_at(flyer.global_position + Vector2(0, -10))
	check(await until(func() -> bool: return p.possessing == flyer, 1.5), "thrown up into the Drifter")

	# The diamond, and the rock off the floor, and back to the Gunman by the
	# door, and into him.
	# Up past the end of the ledge before going over it: under it is a ceiling.
	await fly_to(Vector2(100.0 * Room.CELL, 8.0 * Room.CELL), 16.0)
	await fly_to(gem.global_position + Vector2(0, -8), 6.0)
	check(await until(func() -> bool: return gem.carrier == flyer, 1.0), "the Drifter takes the diamond off the ledge")
	await until(func() -> bool: return rock() != null and rock().resting, 2.0)
	await fly_to(rock().global_position + Vector2(0, -16), 10.0)
	check(await until(func() -> bool: return p.holds("ROCK") and p.weapon_hands() == flyer, 1.0),
		"and the rock off the floor (%.1fs left)" % p.possess_left)
	await fly_to(Vector2(gm2.global_position.x + 112.0, gm2.global_position.y - 24.0), 16.0)
	await throw_at(gm2.global_position + Vector2(0, -30))
	check(await until(func() -> bool: return p.possessing == gm2, 1.5),
		"flown back down the hall and thrown into the Gunman (%.1fs were left)" % last_left)

	# The Gunman carries both to the Crawler that was the gate guard, still
	# standing where the player left it, and the hands go back into that: a
	# guard can be taken again, since POSSESS does it no harm.
	check(await fetch_rock(), "the Gunman picks up the rock")
	check(await fetch_diamond(), "and the diamond the Drifter let go of")
	var shots := [0]
	var count_shots := func(cue: StringName, d: Dictionary) -> void:
		if cue == &"attack" and (d.get("payload") as Payload) != null and (d.get("payload") as Payload).damage >= 40.0:
			shots[0] += 1
	Cues.fired.connect(count_shots)
	check(await hop(g1, 96.0), "and carries them up the first hall into the old gate guard (%.1fs were left)"
		% last_left)
	check(is_equal_approx(g1.health, g1.max_health), "taken twice, and not a scratch on it")
	Cues.fired.disconnect(count_shots)
	check(shots[0] == 0, "and throwing it, the Gunman fires nothing of its own (%d shots)" % shots[0])

	# Out of the gate to the body, and home.
	check(await fetch_rock() and await fetch_diamond(), "which takes both")
	await walk_to(p.global_position.x + 40.0)
	check(p.possessing == g1 and gem.carrier == g1,
		"out of the gate and across the yard to the body (%.1fs left)" % p.possess_left)
	hands.step_out()
	check(await until(func() -> bool: return gem.carrier == null and gem._down > Diamond.SETTLE, 2.0),
		"stepping out lets go of it, and it comes down on the floor")
	await walk_to(gem.global_position.x)
	check(await until(func() -> bool: return gem.carried_by_player(), 1.0), "the body picks it up")
	await walk_to(3.0 * Room.CELL)
	check(await until(func() -> bool: return stolen == 1, 1.0) and screen.over,
		"and carried back into the pit, it is stolen (%.1fs)" % screen.best)

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

	# A throw that hurts nobody gives nothing away, even under a Gunman's nose.
	take_hands()
	var gm := gunman_near(36)
	p.possess(crawler, 5.0)
	p.take_back("ROCK", crawler)
	crawler.global_position = Vector2(gm.global_position.x - 4.0 * Room.CELL, crawler.global_position.y)
	gm.face(-1)
	await frames(4)
	await throw_at(crawler.global_position + Vector2(-200.0, -60.0))
	await wait(1.0)
	check(p.possessing == crawler and not crawler.revealed and not gm._hunts(crawler) and gm.target != crawler,
		"a throw from a guard the player is in that hurts nobody gives nothing away, in front of a Gunman")
	p.release()
	screen.reset_floor()
	await frames(4)
	p = screen.player
	crawler = gate_guard()
	warden = guard("WARDEN")
	flyer = guard("DRIFTER")

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
