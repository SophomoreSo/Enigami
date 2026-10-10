extends Node2D
## A rope: up held with one within reach of the hands takes it, left and right
## swing on it, up and down climb it, a jump lets go of it with the swing's
## speed and a jump on top, and down held at its end drops off it — a tap of
## down there keeps hold. The rules
## alone: what a rope looks like, and the line that runs taut to the hands, are
## rope_test's.
##
## Ropes are a room's (`Room.ropes`): a raid's rooms hang them where the content
## database's `hangings` say, the same ones every time a room is built; a room
## laid by hand hangs none of its own; a made map hangs one down every run of a
## rope or a vine laid in its dressing (`MadeRoom.LINES`), and a vine is taken
## hold of as a rope is.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[SWING] PASS ", what)
	else:
		fails += 1
		push_error("SWING FAIL: " + what)

func phys(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func until(cond: Callable, limit: int = 240) -> bool:
	for i in limit:
		if cond.call():
			return true
		await get_tree().physics_frame
	return bool(cond.call())

func _ready() -> void:
	_rooms()
	await _made()
	print("[SWING] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- where ropes hang ---------------------------------------------------------

func _room(record: Dictionary, seed_base: int) -> Room:
	var room := Room.new()
	add_child(room)
	room.build(Vector2i.ZERO, record.duplicate(true), {}, seed_base)
	return room

func _anchors(room: Room) -> Array:
	return room.ropes.map(func(r: HangingRope) -> Array: return [r.position, r.length, r.kind])

func _rooms() -> void:
	var record := {"kind": "entry", "danger": 1, "region": 0, "variant": 7, "enemies": [], "loot": []}
	var a := _room(record, 12345)
	check(not a.ropes.is_empty(), "a raid's room hangs ropes as it is built (%d)" % a.ropes.size())
	var placed := true
	for r in a.ropes:
		var cell := Vector2i(int(floor(r.position.x / Room.CELL)), int(floor(r.position.y / Room.CELL)))
		if not a.is_solid(cell.x, cell.y - 1) or a.is_solid(cell.x, cell.y) \
				or a.is_solid_at(r.tip() + Vector2(0, Room.CELL)) or r.get_parent() != a or r.held():
			placed = false
	check(placed, "each from rock into open air, stopping short of the floor, the room's own, and held by nobody")
	for row in Db.records("hangings", "", [], "rowid"):
		var kind := String(row["rope"])
		var of_kind: Array = a.ropes.filter(func(r: HangingRope) -> bool: return r.kind == kind)
		var sized := of_kind.all(func(r: HangingRope) -> bool:
			return r.length >= int(row["shortest"]) * Room.CELL and r.length <= int(row["longest"]) * Room.CELL)
		check(of_kind.size() >= int(row["fewest"]) and of_kind.size() <= int(row["most"]) and sized,
			"as many of kind %s as its row says, %d to %d, each %d to %d cells long (%d)"
				% [kind, int(row["fewest"]), int(row["most"]), int(row["shortest"]), int(row["longest"]), of_kind.size()])
	var b := _room(record, 12345)
	check(_anchors(b) == _anchors(a), "the same room hangs the same ropes every time it is built (%s)" % str(_anchors(a)))
	var flat := _room({"kind": "entry", "danger": 1, "region": 0, "variant": 3,
		"flat": true, "enemies": [], "loot": []}, 20260920)
	check(not flat.ropes.is_empty() and flat.ropes.all(func(r: HangingRope) -> bool: return r.position.y == float(Room.CELL)),
		"a flat room hangs its ropes from the ceiling, having nothing else (%s)" % str(_anchors(flat)))
	var named := _room({"kind": "entry", "danger": 1, "region": 0, "variant": 3, "flat": true,
		"enemies": [], "loot": [], "ropes": HideoutWorld.ROPES.duplicate(true)}, 20260920)
	var as_named := named.ropes.size() == HideoutWorld.ROPES.size()
	for i in mini(named.ropes.size(), HideoutWorld.ROPES.size()):
		var r: HangingRope = named.ropes[i]
		var want: Dictionary = HideoutWorld.ROPES[i]
		as_named = as_named and r.position == Vector2((int(want["col"]) + 0.5) * Room.CELL, Room.CELL) \
			and r.length == int(want["cells"]) * Room.CELL and r.kind == "cable"
	check(as_named, "a room whose record names its ropes hangs those, from the rock over each, and rolls none (%s)"
		% str(_anchors(named)))
	# The hideout's: within reach of the hands at the top of a jump and the air
	# jump from the floor, and ending clear of it for a body hanging off the end.
	var floor_y := float(Room.FLOOR_ROW + 1) * Room.CELL
	var standing := floor_y - Player.BODY.y * 0.5
	var leap := Player.JUMP_VELOCITY * Player.JUMP_VELOCITY / (2.0 * Player.GRAVITY) \
		+ Player.DOUBLE_JUMP_VELOCITY * Player.DOUBLE_JUMP_VELOCITY / (2.0 * Player.GRAVITY)
	var hands_at_best := standing - leap - Player.ROPE_HANDS
	var reached := not named.ropes.is_empty()
	var ends: Array = []
	for r in named.ropes:
		ends.append(r.tip().y)
		reached = reached and r.tip().y + Player.ROPE_REACH > hands_at_best \
			and r.tip().y + Player.ROPE_HANDS + Player.BODY.y * 0.5 < floor_y
	check(reached, "the hideout's every one in reach of a jump and the air jump, and clear of the floor (hands get to %.0f; ends at %s)"
		% [hands_at_best, str(ends)])
	named.free()
	var ground := JeanGreyBase.new()
	add_child(ground)
	ground.build(Vector2i.ZERO, {"kind": "entry", "danger": 1, "region": 0, "variant": 0, "enemies": [], "loot": []}, {}, 0)
	check(ground.ropes.is_empty(), "a room laid by hand hangs none of its own (%d)" % ground.ropes.size())
	for room in [a, b, flat, ground]:
		room.free()

## --- a rope in the hands -----------------------------------------------------

## A map twenty cells by twelve, walled round, with a rope laid down column 7
## from under the ceiling, four cells of it, and a vine down column 14, three.
func _map() -> MadeRoom:
	var made := MadeRoom.new()
	var plan := PackedStringArray()
	var dressing := PackedStringArray()
	for y in 12:
		plan.append(MadeRoom.ROCK.repeat(20) if y == 0 or y == 11 else MadeRoom.ROCK + ".".repeat(18) + MadeRoom.ROCK)
		dressing.append(".".repeat(20))
	for y in [1, 2, 3, 4]:
		dressing[y] = ".".repeat(7) + MadeRoom.ROPE + ".".repeat(12)
	for y in [1, 2, 3]:
		dressing[y] = dressing[y].substr(0, 14) + MadeRoom.VINE + dressing[y].substr(15)
	made.plan = plan
	made.dressing = dressing
	add_child(made)
	made.stand()
	return made

func _made() -> void:
	var made := _map()
	check(made.ropes.size() == 2, "a made map hangs a rope down every run of a rope or a vine laid (%d)" % made.ropes.size())
	if made.ropes.size() < 2:
		made.free()
		return
	var rope: HangingRope = made.ropes[0]
	var vine: HangingRope = made.ropes[1]
	check(rope.position == Vector2(7.5 * Room.CELL, Room.CELL) and rope.length == 4.0 * Room.CELL
			and rope.kind == MadeRoom.LINES[MadeRoom.ROPE] and rope.cell == Vector2i(7, 1),
		"from the top of the run, as long as it, a %s (%s, %.0f, %s)" % [MadeRoom.LINES[MadeRoom.ROPE], rope.position, rope.length, rope.cell])
	check(vine.position == Vector2(14.5 * Room.CELL, Room.CELL) and vine.length == 3.0 * Room.CELL
			and vine.kind == MadeRoom.LINES[MadeRoom.VINE] and vine.cell == Vector2i(14, 1),
		"and a vine's as a %s (%s, %.0f, %s)" % [MadeRoom.LINES[MadeRoom.VINE], vine.position, vine.length, vine.cell])

	var p := Player.new()
	p.collision_layer = 2
	p.collision_mask = 1
	add_child(p)
	p.room = made
	var hands := ComputerHands.new()
	p.input.add(hands)
	var mid := rope.anchor() + Vector2(0.0, 80.0 + Player.ROPE_HANDS)

	# Out of reach, up takes nothing.
	p.global_position = mid + Vector2(Player.ROPE_REACH + 14.0, 0.0)
	hands.climb = true
	await phys(3)
	check(not p.on_rope() and not rope.held(), "up held with the hands out of a rope's reach takes nothing")
	hands.climb = false

	# In reach, it does, and the body hangs from it by the hands over its head.
	p.global_position = mid
	p.velocity = Vector2.ZERO
	hands.climb = true
	check(await until(p.on_rope, 10), "up held with a rope within reach of the hands takes it")
	hands.climb = false
	await phys(2)
	check(p.state_name() == "Swing" and rope.held() and rope.holder == p,
		"and the body hangs on it, Swing (%s)" % p.state_name())
	check(absf(rope.hands.distance_to(rope.anchor()) - rope.grip) < 1.0
			and rope.hands.distance_to(p.global_position + Vector2(0.0, -Player.ROPE_HANDS)) < 1.0,
		"the hands on the rope, as far down it as it says, over the body's middle")
	await phys(60)
	check(p.on_rope() and absf(rope.hands.distance_to(rope.anchor()) - rope.grip) < 2.0,
		"left alone it stays on, hanging (%.1f from the anchor, held at %.1f)" % [rope.hands.distance_to(rope.anchor()), rope.grip])

	# A rope hanging still is kicked off the way held, and swings from there:
	# held, the way never keeps it leaned over.
	hands.move = 1.0
	await phys(2)
	var kicked := p._spin * maxf(p._grip, Player.SWING_SHORTEST)
	check(kicked >= Player.SWING_KICK * 0.9, "hanging still, a way held kicks it off that way (%.1f)" % kicked)
	var lo := 0.0
	var hi := 0.0
	for i in 90:
		await phys(1)
		lo = minf(lo, p._swing)
		hi = maxf(hi, p._swing)
	hands.move = 0.0
	check(lo < -0.2 and hi > 0.2,
		"and held, it swings both ways rather than keeping the rope leaned over (%.2f to %.2f)" % [lo, hi])

	# Caught on the move, it swings the way the body was going; pushed along in
	# time with the swing, it goes higher every time.
	hands.jump()
	await until(func() -> bool: return not p.on_rope(), 10)
	await until(func() -> bool: return p.is_on_floor(), 240)
	p.global_position = mid + Vector2(-12.0, 0.0)
	p.velocity = Vector2(220.0, 0.0)
	hands.climb = true
	check(await until(p.on_rope, 10), "taken on the move")
	hands.climb = false
	await phys(2)
	check(p._spin > 0.5, "and set swinging the way the body was going (%.2f)" % p._spin)
	var widest := 0.0
	var fastest := 0.0
	var jolt := 0.0
	var was := p._spin
	for i in 300:
		hands.move = signf(p._spin)
		await phys(1)
		widest = maxf(widest, absf(p._swing))
		fastest = maxf(fastest, absf(p._spin) * maxf(p._grip, Player.SWING_SHORTEST))
		var dt := get_physics_process_delta_time()
		var pulled := Player.GRAVITY * absf(sin(p._swing)) / maxf(p._grip, Player.SWING_SHORTEST) * dt \
			+ absf(was) * (1.0 - exp(-Player.SWING_DAMP * dt))
		# Turned round by the rock it ran into, it keeps SWING_BOUNCE of its speed.
		var kept := absf(was) * (Player.SWING_BOUNCE if signf(p._spin) == -signf(was) and absf(was) > 1.0 else 1.0)
		jolt = maxf(jolt, kept - absf(p._spin) - pulled)
		was = p._spin
	hands.move = 0.0
	check(widest > 0.8, "pushed along in time with the swing it goes higher every time (%.2f)" % widest)
	check(fastest > Player.SWING_FASTEST - 1.0 and fastest <= Player.SWING_FASTEST + 0.01,
		"until it goes as fast as a swing goes, %.0f, and no faster (%.1f)" % [Player.SWING_FASTEST, fastest])
	check(jolt < 0.05, "and nothing takes its speed but the world's pull and the rock it bounces off: no height it is stopped at (%.3f rad/s more than that, at most, in a frame)"
		% jolt)

	# Up and down climb it: up as far as the top, and down as far as the end,
	# where down held a moment longer lets go — and a tap of it does not.
	hands.climb = true
	await phys(90)
	hands.climb = false
	check(p.on_rope() and absf(rope.grip - Player.ROPE_TOP) < 0.01,
		"up climbs it, as high as the top of it and no higher (%.1f)" % rope.grip)
	hands.crouch = true
	var bottom := await until(func() -> bool: return rope.grip >= rope.length, 120)
	hands.crouch = false
	check(bottom and p.on_rope(), "down climbs it, as far as its end, and holds on there (%.1f of %.1f)"
		% [rope.grip, rope.length])
	await phys(2)
	var tap := int(Player.ROPE_LET_GO * 60.0 * 0.5)
	hands.crouch = true
	await phys(tap)
	hands.crouch = false
	await phys(2)
	check(p.on_rope() and rope.held(), "a tap of down at its end keeps hold (%d frames)" % tap)
	hands.crouch = true
	var dropped := await until(func() -> bool: return not p.on_rope(), int(Player.ROPE_LET_GO * 60.0) + 10)
	hands.crouch = false
	check(dropped and not rope.held(), "and down held there %.1fs lets go" % Player.ROPE_LET_GO)
	check(await until(func() -> bool: return p.is_on_floor(), 240), "and the body comes down")

	# Caught faster than a swing goes, it swings no faster than that, and a leap
	# off it flings the body across no faster either.
	p.global_position = mid + Vector2(-12.0, 0.0)
	p.velocity = Vector2(Player.DASH_SPEED, 0.0)
	hands.climb = true
	check(await until(p.on_rope, 10), "taken at a dash")
	hands.climb = false
	var dashed := 0.0
	for i in 30:
		await phys(1)
		dashed = maxf(dashed, absf(p._spin) * maxf(p._grip, Player.SWING_SHORTEST))
	hands.jump()
	await until(func() -> bool: return not p.on_rope(), 10)
	check(dashed <= Player.SWING_FASTEST + 0.01 and absf(p.velocity.x) <= Player.SWING_FASTEST + 1.0,
		"caught at a dash, %.0f, it swings no faster than %.0f, and is leapt off no faster across (%.1f, %.1f)"
			% [Player.DASH_SPEED, Player.SWING_FASTEST, dashed, p.velocity.x])
	await until(func() -> bool: return p.is_on_floor(), 240)

	# A jump leaps off it, with a jump on top of the swing and the air jump back.
	p.global_position = mid + Vector2(-4.0, 0.0)
	p.velocity = Vector2.ZERO
	hands.climb = true
	check(await until(p.on_rope, 10), "taken again")
	await phys(2)
	hands.jump()
	var off := await until(func() -> bool: return not p.on_rope(), 10)
	check(off and p.velocity.y <= Player.ROPE_JUMP + 0.01 and not p._air_jump_used and not rope.held(),
		"a jump lets go of it going up at least %.0f, the air jump handed back (%.1f)" % [Player.ROPE_JUMP, p.velocity.y])
	await phys(12)
	check(not p.on_rope(), "with up still held, the rope just let go of is not caught on the way past")
	hands.climb = false
	await until(func() -> bool: return p.is_on_floor(), 240)
	p.global_position = mid
	p.velocity = Vector2.ZERO
	hands.climb = true
	check(await until(p.on_rope, 10), "and up pressed again takes it again")
	hands.climb = false

	# A vine is taken hold of as a rope is.
	await phys(2)
	hands.jump()
	await until(func() -> bool: return not p.on_rope(), 10)
	await until(func() -> bool: return p.is_on_floor(), 240)
	p.global_position = vine.anchor() + Vector2(-5.0, 48.0 + Player.ROPE_HANDS)
	p.velocity = Vector2.ZERO
	hands.climb = true
	check(await until(p.on_rope, 10) and p.rope == vine and vine.held() and not rope.held(),
		"and a vine is taken hold of as a rope is")
	hands.climb = false
	await phys(2)
	check(p.state_name() == "Swing", "and swung on (%s)" % p.state_name())

	# Out of the room, out of the hands.
	p.room = null
	check(not p.on_rope() and not vine.held(), "a body taken out of the room lets go of its rope")
	p.queue_free()
	made.queue_free()
	await phys(2)
