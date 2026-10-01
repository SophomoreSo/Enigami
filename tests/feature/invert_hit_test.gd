extends Node
## What STUN, and what INVERT makes of the part before it, do once a hit lands:
## the enemy struck is healed, cleansed of every burn, chill and stun, stood
## still where it is; the room round the impact is driven off it; the one
## struck is hauled back the way the attack came.
##
## Driven through `Attacks.resolve_hit`, which is the one door every attack form
## goes through, against dummies and real monsters, the way impact_test is —
## and a real player, for a stun that lands on them. What INVERT puts on the
## payload in the first place is invert_test's.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[INVERT_HIT] PASS ", what)
	else:
		fails += 1
		push_error("INVERT_HIT FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## Physics frames until `cond` holds, or `limit` of them: whether it did.
func until(cond: Callable, limit: int = 240) -> bool:
	for i in limit:
		if cond.call():
			return true
		await get_tree().physics_frame
	return bool(cond.call())

## A dummy that stands still and takes damage, at `at`.
func dummy(at: Vector2, team: int = 1) -> Actor:
	var a := Actor.new()
	a.team = team
	a.max_health = 500.0
	add_child(a)
	a.global_position = at
	return a

## A live monster of `kind`, wired the way the sandbox wires one.
func monster(kind: String, at: Vector2) -> Enemy:
	var e := Enemy.new()
	e.setup(kind, 1, "")
	e.collision_layer = 4
	e.collision_mask = 1
	add_child(e)
	e.global_position = at
	e._patrol_dir = 1
	return e

## A slab of floor centred on `centre`.
func solid(centre: Vector2, size: Vector2) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = centre
	b.add_child(cs)
	add_child(b)

## A hit of `damage` carrying nothing else, to build the others on.
func hit(damage: float = 1.0) -> Payload:
	var p := Payload.new()
	p.damage = damage
	return p

## Rooms for the live-monster checks, kept well apart so one test's push
## cannot reach the next test's monster.
var _plot := 0

func _ready() -> void:
	# Arena.register wants a node to hang loose visuals and Deferred nodes off.
	Arena.register(self)
	await frames(2)
	await _heal()
	await _cleanse()
	await _stun_rule()
	await _stunned_monster()
	await _blocked()
	await _repel()
	await _hook()
	await _stunned_player()
	print("[INVERT_HIT] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- heal -------------------------------------------------------------------

func _heal() -> void:
	var a := dummy(Vector2(0, -2000))
	await frames(1)
	a.health = 400.0
	var given: Array = []
	a.healed.connect(func(_who: Actor, amount: float) -> void: given.append(amount))
	var p := hit(10.0)
	p.heal = 8.0
	Attacks.resolve_hit(p, a, a.global_position, Vector2.ZERO, null, null, 0)
	check(is_equal_approx(a.health, 398.0),
		"a healing hit lands its damage, then gives back its heal (%.0f of 400)" % a.health)
	check(given == [8.0], "and says how much it gave back (%s)" % str(given))
	a.health = a.max_health
	given.clear()
	p.damage = 2.0
	Attacks.resolve_hit(p, a, a.global_position, Vector2.ZERO, null, null, 0)
	check(is_equal_approx(a.health, a.max_health) and given == [2.0],
		"never past the most it has: back what the hit took, and no more (%.0f, gave %s)" % [a.health, str(given)])
	a.queue_free()

	var b := dummy(Vector2(300, -2000))
	await frames(1)
	b.health = 5.0
	var raised: Array = []
	b.healed.connect(func(_who: Actor, amount: float) -> void: raised.append(amount))
	p.damage = 10.0
	Attacks.resolve_hit(p, b, b.global_position, Vector2.ZERO, null, null, 0)
	check(b.dead and raised.is_empty(), "a blow that kills stays a kill: the dead are not healed")

## --- cleanse ----------------------------------------------------------------

func _cleanse() -> void:
	var a := dummy(Vector2(600, -2000))
	await frames(1)
	a.burn_time = 2.0
	a.burn_dps = 3.0
	a.chill_time = 2.0
	a.stun_time = 0.6
	var p := hit()
	p.cleanse = true
	Attacks.resolve_hit(p, a, a.global_position, Vector2.ZERO, null, null, 0)
	check(a.burn_time <= 0.0 and a.burn_dps == 0.0 and a.chill_time <= 0.0 and not a.stunned(),
		"a cleansing hit ends every burn, chill and stun on the enemy struck")
	check(is_equal_approx(a.stun_guard, Actor.STUN_GUARD),
		"and a stun it ends is over like any other, so the guard after one starts (%.1f)" % a.stun_guard)
	a.stun_guard = 0.0
	p.elements.append("FIRE")
	Attacks.resolve_hit(p, a, a.global_position, Vector2.ZERO, null, null, 0)
	check(a.burn_time <= 0.0, "the burn this same hit brought goes with the rest (%.1f)" % a.burn_time)
	a.queue_free()

## --- stun -------------------------------------------------------------------

func _stun_rule() -> void:
	var a := dummy(Vector2(900, -2000))
	await frames(1)
	var p := hit()
	p.stun = 0.5
	Attacks.resolve_hit(p, a, a.global_position, Vector2.ZERO, null, null, 0)
	check(a.stunned() and is_equal_approx(a.stun_time, 0.5), "a STUN hit stuns for its seconds (%.2f)" % a.stun_time)
	check(not a.stun(5.0) and a.stun_time <= 0.5, "another landing on it does not stretch it (%.2f)" % a.stun_time)
	a._process_status(0.6)
	check(not a.stunned() and is_equal_approx(a.stun_guard, Actor.STUN_GUARD), "it wears off, and the guard starts")
	check(not a.stun(0.5), "while the guard is up a fresh stun does not take, so stuns cannot hold one for good")
	a._process_status(Actor.STUN_GUARD + 0.01)
	check(a.stun(0.5), "and once it is down, one does again")
	a.queue_free()

## A CRAWLER on a floor beside something to hunt: stunned, it neither moves,
## casts nor touches; come round, it does all three again. It is stunned
## before its quarry is within reach, so nothing it did before can land in the
## window.
func _stunned_monster() -> void:
	_plot += 1
	var at := Vector2(0, float(_plot) * 4000.0)
	solid(at + Vector2(0, 60), Vector2(3000, 40))
	var quarry := dummy(at + Vector2(400, 0), 0)
	quarry.add_to_group("player")
	var m := monster("CRAWLER", at)
	await frames(1)
	m.global_position = at
	m.max_health = 9999.0
	m.health = 9999.0
	check(await until(func() -> bool: return m.is_on_floor(), 120), "(the crawler stands on the floor)")
	check(m.stun(1.0), "a monster can be stunned")
	quarry.global_position = m.global_position + Vector2(10, 0)
	var hp0 := quarry.health
	var clock0: float = m.runner._elapsed
	await phys(6)
	check(m.target == quarry and m.aggro, "(the crawler has its quarry in sight, and within reach)")
	var x0 := m.global_position.x
	await phys(18)
	check(absf(m.global_position.x - x0) < 1.0,
		"stunned, it stands where it is (%.1fpx)" % absf(m.global_position.x - x0))
	check(is_equal_approx(quarry.health, hp0), "and neither touches nor strikes what it was hunting (%.1f lost)" % (hp0 - quarry.health))
	check(not m.runner.active and is_equal_approx(m.runner._elapsed, clock0),
		"and its board waits with it: nothing on its way lands while it stands there")
	check(await until(func() -> bool: return not m.stunned(), 240), "it comes round")
	check(await until(func() -> bool: return quarry.health < hp0, 240),
		"and goes back to hurting what it hunts (%.1f lost)" % (hp0 - quarry.health))
	quarry.remove_from_group("player")
	quarry.queue_free()
	m.queue_free()
	await frames(2)

## --- what does not land brings nothing --------------------------------------

func _blocked() -> void:
	var a := dummy(Vector2(1200, -2000))
	await frames(1)
	a.health = 400.0
	a.chill_time = 2.0
	a.invuln = 1.0
	var p := hit(10.0)
	p.heal = 8.0
	p.cleanse = true
	p.stun = 0.5
	Attacks.resolve_hit(p, a, a.global_position, Vector2.ZERO, null, null, 0)
	check(is_equal_approx(a.health, 400.0) and a.chill_time > 0.0 and not a.stunned(),
		"a hit that does not land brings nothing with it: no heal, no cleanse, no stun")
	a.queue_free()

## --- repel and hook ------------------------------------------------------------

## How far a `kind` travels in x over half a second while `p` lands 60px to
## its left. Run with and without REPEL, the difference is the push alone.
func push_travel(kind: String, p: Payload) -> float:
	_plot += 1
	var at := Vector2(0, float(_plot) * 4000.0)
	var struck := dummy(at)
	var m := monster(kind, at + Vector2(60, 0))
	await frames(2)
	m.global_position = at + Vector2(60, 0)
	var x0: float = m.global_position.x
	Attacks.resolve_hit(p, struck, struck.global_position, Vector2.RIGHT, null, null, 0)
	await phys(30)
	var moved: float = m.global_position.x - x0
	struck.queue_free()
	m.queue_free()
	return moved

## How far a `kind` travels in x over half a second after `p` strikes it, the
## attack going right.
func knock_travel(kind: String, p: Payload) -> float:
	_plot += 1
	var at := Vector2(0, float(_plot) * 4000.0)
	var m := monster(kind, at)
	await frames(2)
	m.global_position = at
	m.max_health = 9999.0
	m.health = 9999.0
	var x0: float = m.global_position.x
	Attacks.resolve_hit(p, m, m.global_position, Vector2.RIGHT, null, null, 0)
	await phys(30)
	var moved: float = m.global_position.x - x0
	m.queue_free()
	return moved

func _repel() -> void:
	var plain := hit()
	var push := hit()
	push.repel = true
	for kind in ["DUMMY", "CRAWLER", "LOBBER", "DRIFTER"]:
		var driven: float = await push_travel(kind, push) - await push_travel(kind, plain)
		check(driven > 20.0, "a %s 60px from a hit that repels is driven %.0fpx away from it" % [kind, driven])

func _hook() -> void:
	var plain := hit()
	var reel := hit()
	reel.hook = true
	var hauled: float = await knock_travel("DUMMY", reel)
	check(hauled < -20.0, "a dummy struck by a hit going right that hooks is hauled %.0fpx left, back the way it came" % -hauled)
	for kind in ["DUMMY", "CRAWLER", "LOBBER"]:
		var back: float = await knock_travel(kind, reel) - await knock_travel(kind, plain)
		check(back < -40.0, "a %s hooked travels %.0fpx back from where a plain hit sends it" % [kind, -back])

## --- a stunned player ----------------------------------------------------------

func _stunned_player() -> void:
	var pl := Player.new()
	pl.collision_layer = 2
	pl.collision_mask = 1
	add_child(pl)
	await frames(2)
	check(not pl.controls_locked(), "(a player nothing holds)")
	var p := hit()
	p.stun = 0.4
	Attacks.resolve_hit(p, pl, pl.global_position, Vector2.ZERO, null, null, 1)
	await frames(2)
	check(pl.stunned() and pl.controls_locked() and pl.input.held(),
		"a stunned player's hands come off their line, as they do in a conversation")
	check(await until(func() -> bool: return not pl.stunned(), 240), "they come round")
	await frames(2)
	check(not pl.controls_locked(), "and the hands go back on the moment they do")
	pl.queue_free()
