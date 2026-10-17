extends Node2D
## SUMMON BEHAVIOR: what an attack calls up beside itself as it goes off.
## SUMMON PROJECTILE hangs a bolt in the air over where the attack is aimed,
## which falls, strikes what it touches once with the flow, and is gone after
## its life; each one stacked calls one more. SUMMON PET calls a pet that
## follows its summoner, one to a summoner, and goes with them. ANTI-GRAVITY
## takes the weight off a bolt: a lobbed one flies straight, a summoned one
## hangs where it was called.
##
## Headless: nothing here is looked at.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[SUMMON] PASS ", what)
	else:
		fails += 1
		push_error("SUMMON FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func dummy(at: Vector2, team: int) -> Actor:
	var a := Actor.new()
	a.team = team
	a.max_health = 500.0
	add_child(a)
	a.global_position = at
	return a

func bolts() -> Array:
	return get_children().filter(func(c: Node) -> bool: return c is SummonedProjectile and not c.is_queued_for_deletion())

func pets() -> Array:
	return get_tree().get_nodes_in_group("pets").filter(func(c: Node) -> bool: return not c.is_queued_for_deletion())

func cast(p: Payload, by: Actor, aim: Vector2 = Vector2.RIGHT) -> void:
	Attacks.spawn(p, {"attacker": by, "room": null, "team": by.team, "aim": aim, "origin": by.global_position})

func _ready() -> void:
	Arena.register(self)
	await frames(2)
	_the_parts()
	await _the_bolt()
	await _the_pet()
	await _weightless()
	print("[SUMMON] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## Two parts in the SUMMON BEHAVIOR block, with numbers of their own, that put
## their counts on a flow.
func _the_parts() -> void:
	for id in ["SUMMON_PROJECTILE", "SUMMON_PET"]:
		var def := Components.get_def(id)
		check(not def.is_empty() and String(def["cat"]) == Components.CAT_SUMMON_BEHAVIOR and Components.code_of(id) >= 42,
			"%s is a summon part with a number of its own" % id)
	check(Components.categories().has(Components.CAT_SUMMON_BEHAVIOR)
			and not Components.categories().has("pet_behavior"),
		"the block is SUMMON BEHAVIOR, and PET BEHAVIOR is gone")
	var b := SkillBoard.new(4, 5, "s")
	b.set_root("PROJECTILE")
	b.place("SUMMON_PROJECTILE", Vector2i(1, 2), 0)
	b.place("SUMMON_PROJECTILE", Vector2i(2, 2), 0)
	b.place("SUMMON_PET", Vector2i(3, 2), 0)
	var r := SkillRunner.new(b)
	r.base_payload_provider = func() -> Payload: return Weapons.base_payload("GUN")
	var outs: Array = r.simulate()["outputs"]
	var p: Payload = outs[0] if not outs.is_empty() else null
	check(p != null and p.summon_projectile == 2 and p.summon_pet == 1 and p.form == "PROJECTILE",
		"a flow through them carries them, stacked, on top of its form")

## A bolt in the air over the aim: it falls, strikes what is under it once, and
## goes after its life. Two parts, two bolts.
func _the_bolt() -> void:
	var me := dummy(Vector2(0, 0), 0)
	var p := Payload.new()
	p.damage = 10.0
	p.summon_projectile = 1
	cast(p, me)
	var made := bolts()
	check(made.size() == 1, "a flow with one SUMMON PROJECTILE calls one bolt (%d)" % made.size())
	if made.is_empty():
		return
	var b: SummonedProjectile = made[0]
	var start := b.global_position
	check(start.y < me.global_position.y - 60.0 and start.x > me.global_position.x,
		"in the air, over where the attack was aimed (%s)" % str(start))
	check(b.payload.summon_projectile == 0 and b.payload.summon_pet == 0,
		"carrying the flow without its summons")
	var under := dummy(Vector2(start.x, start.y + 120.0), 1)
	var hp := under.health
	await physics(40)
	check(is_instance_valid(b) and b.global_position.y > start.y + 60.0, "it falls by its own weight")
	check(is_equal_approx(hp - under.health, 10.0), "and strikes what it comes down on, once (%.1f)" % (hp - under.health))
	await physics(90)
	check(is_equal_approx(hp - under.health, 10.0), "no more than once")
	var t := 0.0
	while is_instance_valid(b) and not b.is_queued_for_deletion() and t < SummonedProjectile.LIFE + 1.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	check(not is_instance_valid(b) or b.is_queued_for_deletion(), "and is gone after its life")
	p.summon_projectile = 2
	cast(p, me)
	check(bolts().size() == 2, "two SUMMON PROJECTILEs, two bolts (%d)" % bolts().size())
	Attacks.clear_in_flight(self)
	await frames(2)
	check(bolts().is_empty(), "and the bolts are cleared with what else is in flight")
	me.queue_free()
	under.queue_free()

## ANTI-GRAVITY: a lobbed bolt flies without its arc, a summoned bolt hangs.
func _weightless() -> void:
	check(String(Components.get_def("ANTI_GRAVITY").get("cat", "")) == Components.CAT_PROJECTILE_BEHAVIOR
			and Components.code_of("ANTI_GRAVITY") == 44,
		"ANTI-GRAVITY is a projectile behavior, with a number of its own")
	var me := dummy(Vector2(0, 1200), 0)
	var lob := Payload.new()
	lob.form = "PROJECTILE"
	lob.damage = 1.0
	var ctx := {"attacker": me, "room": null, "team": 0, "aim": Vector2.RIGHT,
		"origin": me.global_position, "gravity": true}
	Attacks.spawn(lob, ctx)
	var light := lob.clone()
	light.anti_gravity = 1
	Attacks.spawn(light, ctx)
	var shots := get_children().filter(func(c: Node) -> bool: return c is Projectile and not c.is_queued_for_deletion())
	check(shots.size() == 2 and (shots[0] as Projectile).gravity > 0.0 and is_zero_approx((shots[1] as Projectile).gravity),
		"a lobbed bolt arcs, and with ANTI-GRAVITY it flies straight (%s)"
			% str(shots.map(func(s: Projectile) -> float: return s.gravity)))
	Attacks.clear_in_flight(self)
	var hang := Payload.new()
	hang.summon_projectile = 1
	hang.anti_gravity = 1
	cast(hang, me)
	var made := bolts()
	if made.size() == 1:
		var b: SummonedProjectile = made[0]
		var at := b.global_position
		await physics(40)
		check(is_instance_valid(b) and b.global_position.distance_to(at) < 0.5,
			"a summoned bolt carrying it hangs where it was called (%.1f moved)" % b.global_position.distance_to(at))
	else:
		check(false, "a weightless summoned bolt is called (%d)" % made.size())
	Attacks.clear_in_flight(self)
	me.queue_free()
	await frames(2)

## A pet that follows its summoner: one to a summoner, gone with them.
func _the_pet() -> void:
	var me := dummy(Vector2(400, 0), 0)
	var p := Payload.new()
	p.summon_pet = 1
	cast(p, me)
	check(pets().size() == 1, "a flow with SUMMON PET calls a pet (%d)" % pets().size())
	if pets().is_empty():
		return
	var pet: Pet = pets()[0]
	check(pet.summoner == me, "for whoever cast it")
	cast(p, me)
	check(pets().size() == 1, "and only one: a second cast calls no other (%d)" % pets().size())
	me.global_position = Vector2(900, 200)
	# By the clock, not by frames: a headless run goes through frames far faster
	# than a second a sixtieth at a time.
	var t := 0.0
	while t < 2.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	check(pet.global_position.distance_to(pet.home()) < 12.0,
		"it follows its summoner, over their shoulder (%.0f off)" % pet.global_position.distance_to(pet.home()))
	me.queue_free()
	await frames(3)
	check(pets().is_empty(), "and goes when its summoner does")
