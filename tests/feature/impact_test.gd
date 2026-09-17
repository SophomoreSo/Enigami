extends Node
## The three parts that act at the moment a hit lands, rather than on the way to
## it: GRAVITY drags the room in, SHATTER punishes an enemy frost has already
## slowed, and MANA DRAIN pays the caster back for connecting.
##
## Driven through `Attacks.resolve_hit`, which is the one door every attack form
## goes through — so what is checked here holds for a bolt, an arc, a burst and
## a lunge alike.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[IMPACT] PASS ", what)
	else:
		fails += 1
		push_error("IMPACT FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## A dummy that stands still and takes damage, at `at`.
func dummy(at: Vector2) -> Actor:
	var a := Actor.new()
	a.team = 1
	a.max_health = 500.0
	add_child(a)
	a.global_position = at
	return a

## A board with `ids` in a line, run through the runner so the payload under
## test is the one the rules actually build — not one hand-set here.
func payload_of(ids: Array) -> Payload:
	var b := SkillBoard.new(7, 5, "test")
	b.place("INPUT", Vector2i(0, 2), 0)
	var x := 1
	for id in ids:
		b.place(String(id), Vector2i(x, 2), 0)
		x += 1
	b.place("OUTPUT", Vector2i(x, 2), 0)
	var sim := SkillRunner.new(b)
	sim.base_payload_provider = func() -> Payload: return Weapons.base_payload("SWORD")
	var outs: Array = sim.simulate()["outputs"]
	return outs[0] if outs.size() > 0 else null

func _ready() -> void:
	# Arena.register wants a node to hang loose visuals and Deferred nodes off.
	Arena.register(self)
	await frames(2)

	# --- the parts reach the payload at all ---------------------------------
	var plain := payload_of(["SLASH"])
	check(plain != null and not plain.pull and not plain.shatter and not plain.mana_drain,
		"a board without them carries none of them")
	var loaded := payload_of(["SLASH", "GRAVITY", "SHATTER", "MANA_DRAIN"])
	check(loaded != null and loaded.pull and loaded.shatter and loaded.mana_drain,
		"a board with all three carries all three")
	check(loaded.summary().contains("pulls in") and loaded.summary().contains("chilled")
		and loaded.summary().contains("mana"),
		"and the workbench preview says so (%s)" % loaded.summary())

	# --- SHATTER ------------------------------------------------------------
	var cold := dummy(Vector2(400, 0))
	cold.chill_time = 2.0
	var warm := dummy(Vector2(800, 0))
	var shatter := payload_of(["SLASH", "SHATTER"])
	var before_cold := cold.health
	var before_warm := warm.health
	Attacks.resolve_hit(shatter, cold, cold.global_position, Vector2.RIGHT, null, null, 0)
	Attacks.resolve_hit(shatter, warm, warm.global_position, Vector2.RIGHT, null, null, 0)
	var on_chilled := before_cold - cold.health
	var on_warm := before_warm - warm.health
	check(is_equal_approx(on_chilled, on_warm * Attacks.SHATTER_MUL),
		"SHATTER hits a chilled enemy x%.1f as hard (%.1f against %.1f)"
			% [Attacks.SHATTER_MUL, on_chilled, on_warm])
	check(cold.chill_time > 0.0, "and leaves the chill running, so the next hit shatters too")
	# Without the part, being chilled changes nothing.
	var chilled_again := dummy(Vector2(1200, 0))
	chilled_again.chill_time = 2.0
	var before_plain := chilled_again.health
	Attacks.resolve_hit(plain, chilled_again, chilled_again.global_position, Vector2.RIGHT, null, null, 0)
	check(is_equal_approx(before_plain - chilled_again.health, on_warm),
		"a board without SHATTER hits a chilled enemy no harder")

	# ICE and SHATTER on the same attack: the frost this hit applies is not the
	# frost it shatters, or one part would be doing both halves of the pair.
	var fresh := dummy(Vector2(1600, 0))
	var iced := payload_of(["SLASH", "ICE", "SHATTER"])
	var before_fresh := fresh.health
	Attacks.resolve_hit(iced, fresh, fresh.global_position, Vector2.RIGHT, null, null, 0)
	var first := before_fresh - fresh.health
	check(fresh.chill_time > 0.0, "ICE chills on the first hit")
	check(is_equal_approx(first, iced.damage),
		"which the same hit does not then shatter (%.1f)" % first)
	var before_second := fresh.health
	Attacks.resolve_hit(iced, fresh, fresh.global_position, Vector2.RIGHT, null, null, 0)
	check(is_equal_approx(before_second - fresh.health, iced.damage * Attacks.SHATTER_MUL),
		"but the second hit lands on a chilled enemy and does")

	# --- GRAVITY ------------------------------------------------------------
	# Three enemies around one point: struck, near and far. All of them should
	# end up moving towards it.
	var impact := Vector2(0, 0)
	var struck := dummy(impact + Vector2(20, 0))
	var near := dummy(impact + Vector2(60, 0))
	var far := dummy(impact + Vector2(Attacks.PULL_RADIUS - 10.0, 0))
	var outside := dummy(impact + Vector2(Attacks.PULL_RADIUS + 80.0, 0))
	var pull := payload_of(["SLASH", "GRAVITY"])
	Attacks.resolve_hit(pull, struck, struck.global_position, Vector2.RIGHT, null, null, 0)
	# An arc resolves at the target's own position, so the struck enemy is the
	# point itself: pinned where it stands rather than knocked away.
	check(struck.velocity.is_zero_approx(),
		"GRAVITY pins the struck enemy instead of knocking it back (%s)" % str(struck.velocity))
	check(near.velocity.x < 0.0 and far.velocity.x < 0.0,
		"and drags every other enemy in range onto it")
	check(outside.velocity.is_zero_approx(),
		"but nothing past its reach (%.0f)" % Attacks.PULL_RADIUS)
	check(absf(far.velocity.x) > absf(near.velocity.x),
		"the far edge pulls harder than the near, so the room arrives together (%.0f vs %.0f)"
			% [absf(far.velocity.x), absf(near.velocity.x)])
	# Without the part the struck enemy is knocked away, as it always was.
	var shoved := dummy(Vector2(0, 400))
	Attacks.resolve_hit(plain, shoved, shoved.global_position, Vector2.RIGHT, null, null, 0)
	check(shoved.velocity.x > 0.0, "a board without GRAVITY still knocks its target back")

	# --- MANA DRAIN ---------------------------------------------------------
	var caster := Player.new()
	add_child(caster)
	await frames(2)
	caster.global_position = Vector2(0, 900)
	caster.mana = 20.0
	var victim := dummy(Vector2(200, 900))
	var drain := payload_of(["SLASH", "MANA_DRAIN"])
	Attacks.resolve_hit(drain, victim, victim.global_position, Vector2.RIGHT, caster, null, 0)
	check(is_equal_approx(caster.mana, 20.0 + Attacks.MANA_PER_HIT),
		"MANA DRAIN pays the caster back %.0f a hit (%.1f)" % [Attacks.MANA_PER_HIT, caster.mana])
	# Every connection pays: that is what makes it worth a board that lands often.
	Attacks.resolve_hit(drain, victim, victim.global_position, Vector2.RIGHT, caster, null, 0)
	check(is_equal_approx(caster.mana, 20.0 + Attacks.MANA_PER_HIT * 2.0),
		"and again on the next one (%.1f)" % caster.mana)
	# It never overfills.
	caster.mana = Player.MAX_MANA - 1.0
	Attacks.resolve_hit(drain, victim, victim.global_position, Vector2.RIGHT, caster, null, 0)
	check(is_equal_approx(caster.mana, Player.MAX_MANA),
		"and stops at a full bar (%.1f)" % caster.mana)
	# A board without it takes nothing back.
	caster.mana = 30.0
	Attacks.resolve_hit(plain, victim, victim.global_position, Vector2.RIGHT, caster, null, 0)
	check(is_equal_approx(caster.mana, 30.0), "a board without MANA DRAIN gives nothing back")
	# A monster carrying the part has no mana to fill, and must not error.
	var monster := dummy(Vector2(600, 900))
	Attacks.resolve_hit(drain, victim, victim.global_position, Vector2.RIGHT, monster, null, 1)
	check(true, "an attacker with no mana of its own drains harmlessly")

	# --- the three of them together -----------------------------------------
	var all_cold := dummy(Vector2(0, 1400))
	all_cold.chill_time = 2.0
	var bystander := dummy(Vector2(70, 1400))
	caster.mana = 0.0
	var before_all := all_cold.health
	Attacks.resolve_hit(loaded, all_cold, all_cold.global_position, Vector2.RIGHT, caster, null, 0)
	check(is_equal_approx(before_all - all_cold.health, loaded.damage * Attacks.SHATTER_MUL),
		"one hit can shatter, pull and drain at once — damage")
	check(bystander.velocity.x < 0.0 and all_cold.velocity.is_zero_approx(), "— pull")
	check(is_equal_approx(caster.mana, Attacks.MANA_PER_HIT), "— and drain")

	print("[IMPACT] ---- %d failures ----" % fails)
	get_tree().quit()
