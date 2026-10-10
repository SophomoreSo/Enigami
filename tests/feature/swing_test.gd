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
## laid by hand hangs none of its own; a made map hangs one down every run of
## `MadeRoom.ROPE` laid in its dressing.

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
	var ground := JeanGreyBase.new()
	add_child(ground)
	ground.build(Vector2i.ZERO, {"kind": "entry", "danger": 1, "region": 0, "variant": 0, "enemies": [], "loot": []}, {}, 0)
	check(ground.ropes.is_empty(), "a room laid by hand hangs none of its own (%d)" % ground.ropes.size())
	for room in [a, b, flat, ground]:
		room.free()

## --- a rope in the hands -----------------------------------------------------

## A map twenty cells by twelve, walled round, with a rope laid down column 7
## from under the ceiling, four cells of it.
func _map() -> MadeRoom:
	var made := MadeRoom.new()
	var plan := PackedStringArray()
	var dressing := PackedStringArray()
	for y in 12:
		plan.append(MadeRoom.ROCK.repeat(20) if y == 0 or y == 11 else MadeRoom.ROCK + ".".repeat(18) + MadeRoom.ROCK)
		dressing.append(".".repeat(20))
	for y in [1, 2, 3, 4]:
		dressing[y] = ".".repeat(7) + MadeRoom.ROPE + ".".repeat(12)
	made.plan = plan
	made.dressing = dressing
	add_child(made)
	made.stand()
	return made

func _made() -> void:
	var made := _map()
	check(made.ropes.size() == 1, "a made map hangs a rope down the run of it laid (%d)" % made.ropes.size())
	if made.ropes.is_empty():
		made.free()
		return
	var rope: HangingRope = made.ropes[0]
	check(rope.position == Vector2(7.5 * Room.CELL, Room.CELL) and rope.length == 4.0 * Room.CELL
			and rope.kind == MadeRoom.ROPE_KIND and rope.cell == Vector2i(7, 1),
		"from the top of the run, as long as it, a %s (%s, %.0f, %s)" % [MadeRoom.ROPE_KIND, rope.position, rope.length, rope.cell])

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
	p.global_position = mid + Vector2(6.0, 0.0)
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

	# Left and right swing it.
	var right := 0.0
	hands.move = 1.0
	for i in 40:
		await phys(1)
		right = maxf(right, p._swing)
	var left := 0.0
	hands.move = -1.0
	for i in 80:
		await phys(1)
		left = minf(left, p._swing)
	hands.move = 0.0
	check(right > 0.15 and left < -0.15, "right swings it out to the right, left to the left (%.2f, %.2f)" % [right, left])
	var widest := 0.0
	for k in 10:
		hands.move = 1.0 if k % 2 == 0 else -1.0
		for i in 26:
			await phys(1)
			widest = maxf(widest, absf(p._swing))
	hands.move = 0.0
	check(widest > 0.8 and widest <= Player.SWING_MOST + 0.001,
		"in time with the swing it swings higher every time, never past %.2f (%.2f)" % [Player.SWING_MOST, widest])

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

	# Out of the room, out of the hands.
	p.room = null
	check(not p.on_rope() and not rope.held(), "a body taken out of the room lets go of its rope")
	p.queue_free()
	made.queue_free()
	await phys(2)
