extends Node2D
## ZAP: a beam to where the cursor points, landing the instant it is cast. It
## goes to the cursor and no further than its reach, the first wall on the way
## ends it, and without PIERCE the first enemy on the line takes the whole
## strike and the beam ends there. A monster has no cursor and fires down its
## aim; the stick asks for a share of the reach, as it does of a bolt's.
##
## Driven through `Attacks.spawn`, the door every cast goes through, in a real
## room, so the wall the beam stops at is the room's own. Nothing here draws.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[ZAP] PASS ", what)
	else:
		fails += 1
		push_error("ZAP FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

var room: Room
var player: Player
## Where the last `zap` cue said its beam ended.
var _cue_to: Vector2 = Vector2.INF
var _cues := 0

## A dummy that stands still and takes damage, at `at`.
func dummy(at: Vector2) -> Actor:
	var a := Actor.new()
	a.team = 1
	a.max_health = 500.0
	add_child(a)
	a.global_position = at
	return a

func beam(pierce: int = 0, size: float = 1.0) -> Payload:
	var p := Payload.new()
	p.form = "ZAP"
	p.damage = 10.0
	p.pierce = pierce
	p.size = size
	p.range_px = 320.0
	return p

## Fires `p` from the player at `at`, and hands back the beam it put in the
## world before a frame has passed — so what has happened is what the cast did.
func fire(p: Payload, at: Vector2) -> Zap:
	player.aim_point = at
	var m := at - player.global_position
	if m.length() > 4.0:
		player.aim = m.normalized()
	Attacks.spawn(p, {"attacker": player, "room": room, "team": 0,
		"aim": player.aim, "origin": player.global_position})
	return last_beam()

func last_beam() -> Zap:
	var out: Zap = null
	for c in get_children():
		if c is Zap and not c.is_queued_for_deletion():
			out = c
	return out

func beams() -> int:
	var n := 0
	for c in get_children():
		if c is Zap and not c.is_queued_for_deletion():
			n += 1
	return n

## Every beam gone, and the clock a strike stopped running again.
func settle() -> void:
	for c in get_children():
		if c is Zap:
			remove_child(c)
			c.queue_free()
	TimeCtl.clear()
	await frames(1)

func _ready() -> void:
	Arena.register(self)
	Cues.fired.connect(func(name: StringName, d: Dictionary) -> void:
		if name == &"zap":
			_cues += 1
			_cue_to = d.get("to", Vector2.INF))

	# A flat room with nothing in it: its walls are the border, 32px thick, and
	# the floor is everything from y=640 down.
	room = Room.new()
	add_child(room)
	room.build(Vector2i.ZERO, {"kind": "entry", "danger": 1, "region": 0, "variant": 0,
		"flat": true, "enemies": [], "loot": []}, {}, 1)
	player = Player.new()
	player.collision_layer = 2
	player.collision_mask = 1
	add_child(player)
	player.room = room
	await frames(2)
	# Held still and aimed by hand: the test is where the beam goes, not where
	# the player does.
	player.input_locked = true
	player.set_physics_process(false)
	player.global_position = Vector2(400, 400)
	var d1 := dummy(Vector2(700, 400))
	var d2 := dummy(Vector2(1000, 400))
	var d3 := dummy(Vector2(850, 400))
	await frames(1)

	# --- the part ---------------------------------------------------------------
	var def := Components.get_def("ZAP")
	check(not def.is_empty() and String(def["cat"]) == Components.CAT_FORM and String(def["tag"]) == "ranged",
		"ZAP is a form, and a ranged one")
	check(int(def.get("cells", 0)) == 1 and float(def.get("heat", 0.0)) > 0.0,
		"one cell, and it carries heat (%.2f)" % float(def.get("heat", 0.0)))
	check("ZAP" in Components.loot_pool(), "it drops, forges and shows in the palette")
	var b := SkillBoard.new(7, 5, "zap")
	b.place("INPUT", Vector2i(0, 2), 0)
	b.place("ZAP", Vector2i(1, 2), 0)
	b.place("OUTPUT", Vector2i(2, 2), 0)
	var r := SkillRunner.new(b)
	r.base_payload_provider = func() -> Payload: return Weapons.base_payload("GUN")
	var outs: Array = r.simulate()["outputs"]
	check(outs.size() == 1 and (outs[0] as Payload).form == "ZAP",
		"a flow through it comes out of the OUTPUT as a beam")
	check(Weapons.accepts_board("GUN", b) and Weapons.accepts_board("ROCK", b) and not Weapons.accepts_board("SWORD", b),
		"the gun and the rock carry it, and the sword will not")
	var gun := Weapons.finalize("GUN", (outs[0] as Payload).clone())
	var sword := Weapons.finalize("SWORD", (outs[0] as Payload).clone())
	check(is_equal_approx(gun.damage, float(Weapons.DEFS["GUN"]["base_damage"]) * float(Weapons.DEFS["GUN"]["ranged_mul"]))
			and is_equal_approx(gun.range_px, Payload.BASE_RANGE * float(Weapons.DEFS["GUN"]["reach_mul"])),
		"a weapon weighs it as it weighs a bolt: its ranged damage, its own reach (%.1f dmg, %.0f px)" % [gun.damage, gun.range_px])
	check(gun.range_px > sword.range_px, "so the gun's beam outreaches the sword's (%.0f > %.0f)" % [gun.range_px, sword.range_px])
	GameState.reset_profile()
	var opens_with: Array = []
	for board in GameState.skill_library:
		if board.skill_name == "Zap" and (board as SkillBoard).used_components().has("ZAP"):
			opens_with.append(board)
	check(opens_with.size() == 1, "a new profile's library opens with one, called Zap")

	# --- it lands at once, on what is under the cursor ---------------------------
	var z := fire(beam(), d1.global_position)
	check(z != null and is_equal_approx(d1.health, 490.0),
		"the enemy under the cursor is struck on the frame of the cast (%.0f)" % d1.health)
	check(z != null and z.to.distance_to(d1.global_position) < 0.5,
		"and the beam ends on it, spent")
	check(_cues == 1 and z != null and _cue_to.distance_to(z.to) < 0.5,
		"the cue says where the beam ended")
	check(is_equal_approx(d2.health, 500.0) and is_equal_approx(d3.health, 500.0),
		"nothing past the first enemy is touched")
	await settle()

	# --- it stops at the cursor, and at its reach -------------------------------
	d1.health = 500.0
	z = fire(beam(), Vector2(600, 400))
	check(z != null and z.to.is_equal_approx(Vector2(600, 400)) and is_equal_approx(d1.health, 500.0),
		"aimed short of an enemy, the beam ends on the cursor and the enemy is not touched")
	await settle()
	z = fire(beam(), Vector2(1100, 400))
	check(z != null and is_equal_approx(d1.health, 490.0) and is_equal_approx(d2.health, 500.0),
		"aimed past its reach, it strikes what is inside the reach and not what is beyond")
	await settle()
	d1.global_position = Vector2(1100, 400)
	z = fire(beam(), Vector2(1100, 400))
	check(z != null and z.to.distance_to(Vector2(720, 400)) < 0.5 and is_equal_approx(d1.health, 490.0),
		"and stops at the reach, down the same line (%.0f of %.0f px)" % [z.to.x - 400.0, 320.0])
	await settle()

	# --- PIERCE carries it on ----------------------------------------------------
	# Three in a row, all inside the reach, nearest first.
	d1.global_position = Vector2(560, 400)
	d3.global_position = Vector2(640, 400)
	d2.global_position = Vector2(710, 400)
	d1.health = 500.0
	z = fire(beam(1), Vector2(1100, 400))
	check(z != null and is_equal_approx(d1.health, 490.0) and is_equal_approx(d3.health, 490.0)
			and is_equal_approx(d2.health, 500.0),
		"one PIERCE strikes the first two enemies on the line and not the third")
	check(z != null and z.to.distance_to(d3.global_position) < 0.5,
		"and the beam ends on the last one it had a strike for")
	await settle()
	d1.health = 500.0
	d3.health = 500.0
	z = fire(beam(2), Vector2(1100, 400))
	check(z != null and is_equal_approx(d1.health, 490.0) and is_equal_approx(d3.health, 490.0)
			and is_equal_approx(d2.health, 490.0) and z.to.distance_to(d2.global_position) < 0.5,
		"two PIERCE strike all three, and the beam is spent on the third")
	await settle()
	for d in [d1, d2, d3]:
		d.health = 500.0
	z = fire(beam(3), Vector2(1100, 400))
	check(z != null and is_equal_approx(d2.health, 490.0) and z.to.distance_to(Vector2(720, 400)) < 0.5,
		"with a strike to spare, it goes its whole way")
	await settle()

	# --- SIZE widens it --------------------------------------------------------------
	for d in [d1, d2, d3]:
		d.health = 500.0
	d2.global_position = Vector2(2000, 2000)
	d3.global_position = Vector2(2000, 2100)
	d1.global_position = Vector2(700, 425)
	z = fire(beam(), Vector2(900, 400))
	check(z != null and is_equal_approx(d1.health, 500.0),
		"an enemy %.0f px off the line is clear of a beam at size 1" % 25.0)
	await settle()
	z = fire(beam(0, 2.0), Vector2(900, 400))
	check(z != null and is_equal_approx(d1.health, 490.0), "and inside one at size 2")
	await settle()

	# --- a cursor on the caster, and a caster with no cursor ---------------------
	d1.health = 500.0
	d1.global_position = Vector2(2000, 2200)
	player.aim = Vector2.RIGHT
	z = fire(beam(), player.global_position + Vector2(3, 0))
	check(z != null and z.to.distance_to(Vector2(720, 400)) < 0.5,
		"a cursor on top of the caster fires the beam down the aim, its whole reach")
	await settle()
	d1.global_position = Vector2(600, 400)
	z = fire(beam(), player.global_position + Vector2(3, 0))
	check(z != null and is_equal_approx(d1.health, 490.0) and z.to.distance_to(d1.global_position) < 0.5,
		"and strikes what stands down it")
	await settle()
	var caster := Actor.new()
	caster.team = 1
	add_child(caster)
	caster.global_position = Vector2(400, 200)
	await frames(1)
	Attacks.spawn(beam(), {"attacker": caster, "room": room, "team": 1,
		"aim": Vector2.RIGHT, "origin": caster.global_position})
	z = last_beam()
	check(z != null and z.to.distance_to(Vector2(720, 200)) < 0.5,
		"an attacker with no cursor — a monster — fires down its aim, its whole reach")
	await settle()
	Attacks.spawn(beam(), {"attacker": caster, "room": room, "team": 1,
		"aim": Vector2.RIGHT, "origin": caster.global_position, "reach": 0.0})
	z = last_beam()
	check(z != null and is_equal_approx(z.to.distance_to(z.from), 320.0 * Attacks.REACH_MIN),
		"and the stick asks for its share of that reach, as it does of a bolt's (%.0f px)" % z.to.distance_to(z.from))
	await settle()
	caster.queue_free()
	await frames(1)

	# --- the first wall on the way ends it ---------------------------------------------
	d1.health = 500.0
	player.global_position = Vector2(1000, 400)
	d1.global_position = Vector2(1300, 400)
	z = fire(beam(), Vector2(1400, 400))
	check(z != null and z.to.x < float(Room.W - 1) * Room.CELL and z.to.x > 1230.0,
		"a beam aimed through the wall stops at the wall (x %.0f of %d)" % [z.to.x, (Room.W - 1) * Room.CELL])
	check(is_equal_approx(d1.health, 500.0), "and nothing behind the wall is struck")
	await settle()
	player.global_position = Vector2(400, 400)
	d1.global_position = Vector2(700, 400)

	# --- a volley lands beam after beam on the same point -----------------------------
	var volley := beam()
	volley.duplicates = 3
	z = fire(volley, d1.global_position)
	var seen: Array = []
	for i in 90:
		for c in get_children():
			if c is Zap and not seen.has(c):
				seen.append(c)
		if seen.size() >= 3:
			break
		await get_tree().process_frame
	check(seen.size() == 3, "DUPLICATE x3 is three beams, one after another (%d)" % seen.size())
	check(is_equal_approx(d1.health, 470.0), "each landing on the enemy under the cursor (%.0f)" % d1.health)
	await settle()

	# --- a trigger's follow-up ------------------------------------------------------------
	d1.health = 500.0
	var chained := beam()
	chained.on_hit = beam()
	z = fire(chained, d1.global_position)
	seen.clear()
	for i in 90:
		for c in get_children():
			if c is Zap and not seen.has(c):
				seen.append(c)
		if seen.size() >= 2:
			break
		await get_tree().process_frame
	check(seen.size() == 2 and is_equal_approx(d1.health, 480.0),
		"an ON HIT beam fires from the hit, a beat later, and lands too (%d beams, %.0f)" % [seen.size(), d1.health])
	await settle()

	# --- swept with everything else in flight ---------------------------------------------
	fire(beam(), Vector2(600, 400))
	check(beams() == 1, "a beam still on screen is in flight")
	Attacks.clear_in_flight(self)
	await frames(1)
	check(beams() == 0, "and is swept with the rest when the ground changes")

	print("[ZAP] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)
