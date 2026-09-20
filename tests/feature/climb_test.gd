extends Node2D
## Going up a room and staying there.
##
## A room is entered from below through the hole its own south door is: the
## floor is carved away across those columns so a body can drop through to the
## room underneath. Put down standing in that hole, a player fell straight back
## through it and the two rooms traded them back and forth — north was a door
## that could not be walked through. What is checked here is that the arrival is
## moved onto the floor beside the hole, and that a raid taken north stays north.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[CLIMB] PASS ", what)
	else:
		fails += 1
		push_error("CLIMB FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / Room.CELL)), int(floor(p.y / Room.CELL)))

func _ready() -> void:
	Arena.register(self)
	_doorway()
	await _raid()
	print("[CLIMB] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- the room's own answer --------------------------------------------------
func _doorway() -> void:
	var r := Room.new()
	add_child(r)
	r.build(Vector2i(2, 2), {"kind": "normal", "danger": 1, "variant": 7},
		{Components.N: true, Components.S: true}, 4242)

	# The premise: the door you come up through is a hole, so the spot the door
	# itself names has nothing under it.
	var doorway := Room.arrival_point(Components.S)
	check(not r._catches(cell_of(doorway)),
		"the south doorway has nothing under it — that is the hole you came up")

	var at := r.entry_point(Components.S)
	check(r._standable(cell_of(at)),
		"a player arriving from below is put down on floor (%s)" % str(cell_of(at)))
	check(r._catches(cell_of(at)), "with something under them to stand on")
	for dir in r.doors:
		check(not r.door_rect(int(dir)).has_point(at),
			"and clear of the doorway itself, so they are not sent straight back")
	check(absf(at.x - doorway.x) < Room.CELL * 6.0,
		"beside the door rather than across the room (%.0f px)" % absf(at.x - doorway.x))

	# Dropping in from above is still dropping in: that arrival is only moved
	# when the room would not catch the body at all.
	var top := r.entry_point(Components.N)
	check(r._catches(cell_of(top)), "a player arriving from above lands in the room")

	# A side door levels its own floor, so those arrivals were never in danger
	# and are left exactly where they were.
	var side := Room.new()
	add_child(side)
	side.build(Vector2i(3, 2), {"kind": "normal", "danger": 1, "variant": 3},
		{Components.W: true, Components.E: true}, 99)
	check(side.entry_point(Components.W) == Room.arrival_point(Components.W),
		"an arrival with floor under it is left where the door put it")
	r.queue_free()
	side.queue_free()

## --- the raid, walked north -------------------------------------------------
func _raid() -> void:
	GameState.deploy("GUN", [0])
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
	await frames(2)
	# Into the north doorway, which is what walking into it comes to.
	raid.player.global_position = raid.room.door_rect(Components.N).get_center()
	await frames(3)
	check(raid.room.coord == above, "walking into the north door moves the raid up (%s)" % str(raid.room.coord))

	# And it stays moved. Long enough for a fall through the floor to have
	# taken them back, which is the bug this is here for.
	await frames(40)
	check(raid.room.coord == above,
		"and a second later they are still up there (%s)" % str(raid.room.coord))
	check(raid.player.is_on_floor(), "standing on the floor of the room they walked into")
	check(not raid.room.door_rect(Components.S).has_point(raid.player.global_position),
		"and not in the hole they came up through")
	raid.queue_free()
	await frames(2)
