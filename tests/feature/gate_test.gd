extends Node2D
## Going up a room and down again, through its gates.
##
## Rooms side by side are joined by doorways, walked through. Rooms one over the
## other are joined by a gate on each floor — the lower room's leads up, the
## upper room's down — gone through with interact. No room has a hole in its
## ceiling to jump up into or one in its floor to fall through, so the way up
## is never a climb. What is checked here is that a room with rooms above and
## below stands its two gates on the floor, with nothing in front of them and
## nothing of its own put down at them; that interact at one moves the raid
## through it, onto the floor in front of the gate back, and that it stays
## there; and that walking past a gate does nothing.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[GATE] PASS ", what)
	else:
		fails += 1
		push_error("GATE FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / Room.CELL)), int(floor(p.y / Room.CELL)))

## Interact, down and up again, as a key does it.
func press() -> void:
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(2)

func _ready() -> void:
	Arena.register(self)
	_room()
	await _raid()
	print("[GATE] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- the room's own answer --------------------------------------------------
func _room() -> void:
	var r := Room.new()
	add_child(r)
	r.build(Vector2i(2, 2), {"kind": "normal", "danger": 1, "variant": 7},
		{Components.N: true, Components.S: true, Components.E: true}, 4242)
	check(r.gates.size() == 2 and r.gates.has(Components.N) and r.gates.has(Components.S),
		"a room with rooms above and below it has a gate for each (%s)" % str(r.gates.keys()))
	check(r.doors.size() == 1 and r.doors.has(Components.E),
		"and a doorway only in the wall with a room beyond it (%s)" % str(r.doors.keys()))
	var holes := 0
	for x in Room.W:
		if not r.is_solid(x, 0) or not r.is_solid(x, Room.H - 1) or not r.is_solid(x, Room.H - 2):
			holes += 1
	check(holes == 0, "no hole in its ceiling to jump into, or in its floor to fall through (%d)" % holes)
	for dir in r.gates:
		var g: Gate = r.gates[dir]
		var way := "up" if dir == Components.N else "down"
		var c := cell_of(g.position)
		check(c.y == Room.FLOOR_ROW and r._standable(c),
			"the gate %s stands on the room's own floor (%s)" % [way, str(c)])
		var open := true
		for x in range(c.x - 1, c.x + 2):
			for y in range(Room.FLOOR_ROW - Room.GATE_ROWS + 1, Room.FLOOR_ROW + 1):
				open = open and not r.is_solid(x, y)
		check(open, "with nothing in front of it or over it: it is walked up to")
		check(Room.arrival_point(dir) == g.position and r.entry_point(dir) == g.position,
			"and it is where a body that comes through the other is put down")
	var clear := true
	for rec in (r.data["enemies"] as Array) + (r.data["loot"] as Array) + (r.data["digs"] as Array):
		var at: Array = (rec as Dictionary).get("pos", [])
		if at.size() == 2:
			var c := cell_of(Vector2(float(at[0]), float(at[1])))
			clear = clear and not r._by_a_gate(c.x, c.y)
	check(clear, "nothing the room is filled with is put down at a gate")
	# A room beside others and nothing else has no gate at all.
	var side := Room.new()
	add_child(side)
	side.build(Vector2i(3, 2), {"kind": "normal", "danger": 1, "variant": 3},
		{Components.W: true, Components.E: true}, 99)
	check(side.gates.is_empty() and side.doors.size() == 2, "a room with nothing above or below has no gate")
	r.queue_free()
	side.queue_free()

## --- the raid, gone up and down ---------------------------------------------
func _raid() -> void:
	GameState.reset_profile()
	GameState.raid_seed = 20260919
	GameState.deploy("GUN")
	var raid := Raid.new()
	raid.finished.connect(func(_r: String, _p: Dictionary) -> void: raid.queue_free())
	add_child(raid)
	await frames(4)

	# Somewhere on this floor with a room above it.
	var below := Vector2i(-1, -1)
	for key in raid.map.rooms:
		var c: Vector2i = key
		if raid.map.has_room(c + Vector2i(0, -1)):
			below = c
			break
	check(below.x >= 0, "the map has a room with another above it (%s)" % str(below))
	if below.x < 0:
		return
	var above: Vector2i = below + Vector2i(0, -1)

	raid._enter_room(below, -1)
	await frames(3)
	var up: Gate = raid.room.gates.get(Components.N)
	check(up != null, "which has a gate up")
	if up == null:
		return
	# Walked past, a gate does nothing.
	raid.player.global_position = up.global_position + Vector2(Room.CELL * 6.0, 0.0)
	await frames(10)
	raid.player.global_position = up.global_position
	raid.player.velocity = Vector2.ZERO
	await frames(10)
	check(raid.room.coord == below, "standing at it, nothing happens until interact is pressed")
	check(up.offered() and raid.use_nearby(),
		"but interact would take them through, and the console's USE says so")
	await press()
	check(raid.room.coord == above, "interact at the gate up moves the raid up (%s)" % str(raid.room.coord))

	# And it stays moved: long enough for any fall to have taken them back.
	await frames(40)
	var down: Gate = raid.room.gates.get(Components.S)
	check(raid.room.coord == above and raid.player.is_on_floor(),
		"a second later they are still up there, on the floor (%s)" % str(raid.room.coord))
	check(down != null and absf(raid.player.global_position.x - down.global_position.x) < 4.0,
		"in front of the gate down, which is the way back")
	await press()
	check(raid.room.coord == below, "interact at the gate down takes them back down (%s)" % str(raid.room.coord))
	await frames(20)
	var back: Gate = raid.room.gates.get(Components.N)
	check(back != null and back.offered() and raid.player.is_on_floor(),
		"standing at the gate up they went through")
	raid.queue_free()
	await frames(2)
