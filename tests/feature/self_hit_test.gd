extends Node2D
## What can strike the player who made it: a NEAR they cast touches them too,
## standing in its reach, with what came after it on the flow — a HEAL heals
## them — while a monster's NEAR spares the monster that cast it; and a thrown
## rock or rune strikes whoever threw it, once it has been clear of their hand
## and not before.
##
## Headless: nothing here is looked at.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[SELF] PASS ", what)
	else:
		fails += 1
		push_error("SELF FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func seconds(s: float) -> void:
	var t := 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()

## `ids` in a line, the first on the root, on a board exactly as long.
func board_of(ids: Array) -> SkillBoard:
	var b := SkillBoard.new(ids.size(), 5, "test")
	b.set_root(String(ids[0]))
	for i in range(1, ids.size()):
		b.place(String(ids[i]), Vector2i(i, 2), 0)
	return b

func flow(ids: Array, weapon: String = "SWORD") -> Payload:
	var r := SkillRunner.new(board_of(ids))
	r.base_payload_provider = func() -> Payload: return Weapons.base_payload(weapon)
	var outs: Array = r.simulate()["outputs"]
	return outs[0] as Payload if not outs.is_empty() else null

func _ready() -> void:
	GameState.reset_profile()
	Arena.register(self)
	await frames(2)
	await _near_heals()
	await _monster_near()
	await _thrown_back()
	GameState.reset_profile()
	print("[SELF] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## A NEAR with no form, a HEAL after it, cast by the player where they stand:
## the player is in its reach, and healed.
func _near_heals() -> void:
	var p := Player.new()
	add_child(p)
	await frames(2)
	p.global_position = Vector2(0, 0)
	p.health = p.max_health - 30.0
	p.invuln = 0.0
	var heal := flow(["NEAR", "HEAL"])
	check(heal != null and heal.near > 0 and heal.form == "", "NEAR then HEAL is a flow with no form, a NEAR on it")
	var was := p.health
	Attacks.spawn(heal, {"attacker": p, "room": null, "team": p.team, "aim": Vector2.RIGHT, "origin": p.global_position})
	await seconds(0.5)
	check(p.health > was, "the player's own NEAR touches them, and its HEAL heals them (%.0f from %.0f)" % [p.health, was])
	p.queue_free()
	await frames(2)

## The same NEAR cast by a monster: the monster that cast it is not touched.
func _monster_near() -> void:
	var e := Enemy.new()
	e.setup("DUMMY", 1, "")
	add_child(e)
	await frames(2)
	e.global_position = Vector2(0, 2000)
	var hurt := flow(["NEAR", "DAMAGE"])
	hurt.damage = 20.0
	var was := e.health
	Attacks.spawn(hurt, {"attacker": e, "room": null, "team": e.team, "aim": Vector2.RIGHT, "origin": e.global_position})
	await seconds(0.5)
	check(is_equal_approx(e.health, was), "a monster's NEAR spares the monster that cast it")
	e.queue_free()
	await frames(2)

## A thrown rock: not the thrower as it leaves their hand; the thrower once it
## has been clear of them and comes round to them.
func _thrown_back() -> void:
	var p := Player.new()
	add_child(p)
	await frames(2)
	p.global_position = Vector2(0, 4000)
	p.invuln = 0.0
	var rock := Weapons.finalize("ROCK", flow(["PROJECTILE"], "ROCK"))
	rock.damage = 7.0
	var was := p.health
	Attacks.spawn(rock, {"attacker": p, "room": null, "team": p.team, "aim": Vector2.RIGHT,
		"origin": p.global_position, "thrown": "ROCK", "thrower": p})
	await frames(2)
	check(is_equal_approx(p.health, was), "a thrown rock does not strike its thrower on the way out of their hand")
	var bolt: Projectile = null
	for c in get_children():
		if c is Projectile and not c.is_queued_for_deletion():
			bolt = c
	check(bolt != null and bolt.thrown == "ROCK", "it is in the air")
	if bolt == null:
		return
	# Clear of the thrower now; the thrower steps into its way, ahead of it.
	await seconds(0.15)
	p.invuln = 0.0
	p.global_position = bolt.global_position + bolt.velocity.normalized() * 60.0
	await seconds(0.4)
	check(p.health < was, "once it has left their hand, it strikes whoever threw it (%.0f from %.0f)" % [p.health, was])
	check(Weapons.is_thrown("RUNE"), "the rune is thrown the same way, and is held to the same")
	p.queue_free()
	await frames(2)
