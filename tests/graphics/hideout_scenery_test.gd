extends Node
## The hideout's scenery (`HideoutScenery`): the city through its glass and the
## room's own fittings, drawn in code a pixel of the buffer at a time.
##
## What this holds to. The room is dressed in it: it stands in the room's own
## view, in front of the tiles and behind everything that hangs, grows or
## moves. It was laid out for the room it is in — its edges are the room's, and
## what it stands at each station stands on the floor under that station, with
## the station's sign hung clear over it. The city is the same city every time.
## What is out there to be read stays clear of the posts between the panes,
## however far its depth slides; the depths slide by whole pixels of the
## buffer, the nearest furthest, as the player walks the room; and none of it,
## at either end of the room, shows past the room's own walls. A station's
## fittings light when the player is at one that would answer, and the gate's
## ring is in the colour of whether it would. And a frame costs what moves and
## no more: the towers and the room are drawn once.
##
## Needs a real renderer: what shows is read off the frame.

const GameScript := preload("res://app/game.gd")
const S := HideoutScenery.S
## What drawing everything that moves may cost, in boxes: half as much again
## as it does.
const BUDGET := 1000

var game: Node
var world: HideoutWorld
var view: HideoutWorldView
var scenery: HideoutScenery
var bot: ComputerHands
var fails := 0
var _drawn := false

func check(ok: bool, what: String) -> void:
	if ok:
		print("[SCENERY] PASS ", what)
	else:
		fails += 1
		push_error("SCENERY FAIL: " + what)

## A frame, with the window kept drawing: a covered one on macOS draws nothing.
func tick() -> void:
	await get_tree().process_frame
	if not DisplayServer.window_can_draw():
		RenderingServer.force_draw(false)

## By the clock: a test window runs at whatever rate it likes.
func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await tick()
		t += get_process_delta_time()

## Until `cond`, or `most` seconds.
func settle(cond: Callable, most: float = 2.0) -> bool:
	var t := 0.0
	while t < most:
		if cond.call():
			return true
		await tick()
		t += get_process_delta_time()
	return bool(cond.call())

## The frame on screen, once one has been drawn.
func frame() -> Image:
	_drawn = false
	var t := 0.0
	while not _drawn and t < 2.0:
		await tick()
		t += get_process_delta_time()
	return get_viewport().get_texture().get_image()

## Where a rect of the room's buffer pixels lands on the screen.
func on_screen(x: int, y: int, w: int, h: int) -> Rect2i:
	var onto := get_viewport().get_final_transform() * get_viewport().get_canvas_transform() \
		* scenery.global_transform
	var r: Rect2 = onto * Rect2(x * S, y * S, w * S, h * S)
	return Rect2i(Vector2i(r.position.round()), Vector2i(r.size.round()))

func stand(x: float) -> void:
	world.player.global_position = Vector2(x, world.player.global_position.y)
	world.player.velocity = Vector2.ZERO

func stand_at(id: String) -> void:
	stand((world.stations[id] as Station).global_position.x)

func _ready() -> void:
	RenderingServer.frame_post_draw.connect(func() -> void: _drawn = true)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	GameState.reset_profile()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await wait(0.2)
	game.goto_hideout()
	world = game.current
	await settle(func() -> bool: return (Views.of(world) as HideoutWorldView).scenery != null)
	view = Views.of(world)
	scenery = view.scenery
	# The computer's hands, so the crosshair stays where it is put and nobody's
	# mouse moves anything while frames are being compared.
	bot = ComputerHands.new()
	world.player.input.add(bot)
	bot.point_at(Vector2(640, 600))
	await wait(0.4)

	_dressed()
	_laid_out()
	_clear_of_the_posts()
	_same_city()
	await _slides()
	await _lights()
	await _cost()
	await _shows()
	await _stays_in_the_room()

	print("[SCENERY] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- where it stands --------------------------------------------------------

func _dressed() -> void:
	var room_view := Views.of(world.room) as RoomView
	check(scenery != null and scenery.get_parent() == room_view,
		"the hideout's room is dressed: the scenery stands in the room's own view")
	if scenery == null:
		return
	check(scenery.get_index() == room_view._tiles.get_index() + 1 and scenery.z_index == room_view._tiles.z_index,
		"straight in front of the tiles (%d after %d)" % [scenery.get_index(), room_view._tiles.get_index()])
	var behind := true
	for n in room_view.ropes + room_view.plants:
		if (n as Node).get_index() < scenery.get_index():
			behind = false
	check(behind and not (room_view.ropes + room_view.plants).is_empty(),
		"and behind everything the room hangs and grows (%d cables, %d patches)"
			% [room_view.ropes.size(), room_view.plants.size()])
	check(scenery.z_index < 0, "which puts it behind whoever walks the room too")

func _laid_out() -> void:
	var room := world.room
	check(HideoutScenery.LEFT * S == Room.CELL and HideoutScenery.RIGHT * S == (Room.W - 1) * Room.CELL
			and HideoutScenery.TOP * S == Room.CELL,
		"it was laid out for a room this size: its walls and ceiling are the room's")
	var open_all_the_way := true
	for x in range(1, Room.W - 1):
		for y in range(1, int(HideoutScenery.FLOOR * S / Room.CELL)):
			if room.is_solid(x, y):
				open_all_the_way = false
		if not room.is_solid(x, int(HideoutScenery.FLOOR * S / Room.CELL)):
			open_all_the_way = false
	check(open_all_the_way, "and its floor is the room's: open above it from wall to wall, solid under")
	for id in world.stations:
		var s: Station = world.stations[id]
		var at: Vector2i = scenery._at[id]
		check(at.x * S == roundi(s.global_position.x) and at.y == HideoutScenery.FLOOR,
			"what stands at the %s stands on the floor under it (%s for %s)" % [id, str(at), str(s.global_position)])
		var plate := view._plate(s)
		check(plate.end.y <= (HideoutScenery.FLOOR - HideoutScenery.TALLEST) * S,
			"with its sign hung clear over it (the plate ends at %.0f, the tallest thing starts at %d)"
				% [plate.end.y, (HideoutScenery.FLOOR - HideoutScenery.TALLEST) * S])
	check(HideoutScenery.GLASS_LEFT - HideoutScenery.SLIDE * 2 >= HideoutScenery.LEFT,
		"a depth slid all the way over still ends behind the left pillar")
	check(HideoutScenery.GLASS_RIGHT + HideoutScenery.SLIDE * 2 <= HideoutScenery.RIGHT,
		"and behind the gate's bay on the right")

## Everything out in the city that is there to be read, however far it slides.
func _clear_of_the_posts() -> void:
	for board in HideoutScenery.SIGNS + HideoutScenery.SCREENS:
		var at: Vector2i = board["at"]
		var size: Vector2i = board["size"]
		var from := at.x - HideoutScenery.SLIDE
		var to := at.x + size.x + HideoutScenery.SLIDE
		var clear := from >= HideoutScenery.GLASS_LEFT and to <= HideoutScenery.GLASS_RIGHT
		for post: int in HideoutScenery.POSTS:
			if from < post + 3 and to > post:
				clear = false
		check(clear and at.y >= HideoutScenery.GLASS_TOP and at.y + size.y <= HideoutScenery.SILL,
			"%s stays in one pane of the glass, clear of the posts (%d to %d)"
				% [String(board.get("says", "a screen")), from, to])

func _same_city() -> void:
	var again := HideoutScenery.new()
	add_child(again)
	check(str(again._far_towers) == str(scenery._far_towers) and str(again._mid_towers) == str(scenery._mid_towers)
			and str(again._near_towers) == str(scenery._near_towers) and not scenery._mid_towers.is_empty(),
		"the city is the same city every time (%d, %d and %d towers)"
			% [scenery._far_towers.size(), scenery._mid_towers.size(), scenery._near_towers.size()])
	again.free()

## --- what it does -----------------------------------------------------------

func _slides() -> void:
	var most := float(HideoutScenery.SLIDE * S)
	stand(60.0)
	await settle(func() -> bool: return scenery._near.position.x == most)
	var left := [scenery._far.position.x, scenery._mid.position.x, scenery._near.position.x]
	check(left[2] == most and left[0] > 0.0 and left[0] < left[1] and left[1] < left[2],
		"at the left wall the city has slid right, the nearest towers furthest (%s)" % str(left))
	stand(1220.0)
	await settle(func() -> bool: return scenery._near.position.x == -most)
	var right := [scenery._far.position.x, scenery._mid.position.x, scenery._near.position.x]
	check(right[2] == -most and right[0] < 0.0 and right[0] > right[1] and right[1] > right[2],
		"and at the right wall, left (%s)" % str(right))
	var whole := true
	for x: float in left + right:
		if fmod(x, float(S)) != 0.0:
			whole = false
	check(whole, "by whole pixels of the buffer")
	check(scenery._signs.position == scenery._near.position and scenery._traffic.position == scenery._mid.position
			and scenery._rain.position == Vector2.ZERO and scenery._wall.position == Vector2.ZERO,
		"what moves out there slides with its depth; the rain and the room do not slide at all")
	stand(640.0)
	await settle(func() -> bool: return scenery._near.position.x == 0.0)
	check(scenery._near.position.x == 0.0 and scenery._far.position.x == 0.0, "and from the middle of the room it is all square")

func _lights() -> void:
	var gate: Station = world.stations["gate"]
	# Between the rack and the counter, out of reach of both.
	stand(480.0)
	await settle(func() -> bool:
		return float(scenery._lit["weapons"]) == 0.0 and float(scenery._lit["shop"]) == 0.0 and float(scenery._lit["gate"]) == 0.0)
	check(float(scenery._lit["weapons"]) == 0.0 and float(scenery._lit["shop"]) == 0.0 and float(scenery._lit["gate"]) == 0.0,
		"with nobody at a station, nothing is lit for one (%s)" % str(scenery._lit))
	for id in ["weapons", "shop", "gate"]:
		stand_at(id)
		# Waited for together: what the player has just left goes out as this
		# comes on, and the two need not land in the same frame.
		check(await settle(func() -> bool: return float(scenery._lit[id]) == 1.0 and _lit_elsewhere(id) == 0.0),
			"standing at the %s lights what stands there, and nothing else (%s)" % [id, str(scenery._lit)])
	# The gate, shut: it stands there dark, whoever is at it.
	gate.open = false
	stand_at("gate")
	await wait(0.6)
	check(not scenery._gate_open() and float(scenery._lit["gate"]) == 0.0,
		"a gate that would not open lights for nobody (%.2f)" % float(scenery._lit["gate"]))
	gate.open = true
	check(await settle(func() -> bool: return float(scenery._lit["gate"]) == 1.0), "and lights again once it would")
	# Its lamps, read with nobody standing in front of them.
	stand(480.0)
	var open := await _ring_colour()
	gate.open = false
	var shut := await _ring_colour()
	gate.open = true
	check(shut.r > shut.g * 1.5 and open.g > open.r * 1.5,
		"its ring is lit red while it is shut and green once it is open (%s, then %s)" % [str(shut), str(open)])

## How lit the stations other than `id` are, all told.
func _lit_elsewhere(id: String) -> float:
	var sum := 0.0
	for other in scenery._lit:
		if other != id:
			sum += float(scenery._lit[other])
	return sum

## What colour the gate's lamps are, over a second of them: every lit pixel
## round the top of the rim, clear of what grows at the foot of it, added up.
func _ring_colour() -> Color:
	var g: Vector2i = scenery._at["gate"]
	var ring := on_screen(g.x - 32, g.y - HideoutScenery.TALLEST - 2, 64, 44)
	var sum := Color(0, 0, 0)
	for look in 4:
		await wait(0.25)
		var im := await frame()
		for y in range(ring.position.y, ring.end.y, 2):
			for x in range(ring.position.x, ring.end.x, 2):
				var c := im.get_pixel(x, y)
				# Lamps, not steel: a colour, and a bright one.
				if maxf(c.r, c.g) > 0.35 and absf(c.r - c.g) > 0.15:
					sum += c
	return sum

func _cost() -> void:
	stand(480.0)
	await wait(0.3)
	var still: Array = [scenery._far, scenery._mid, scenery._near, scenery._wall, scenery._fittings]
	var moving: Array = [scenery._beams, scenery._traffic, scenery._signs, scenery._rain, scenery._wall_life, scenery._life]
	var was: Array = (still + moving).map(func(l: HideoutScenery.Layer) -> int: return l.painted)
	var before := HideoutScenery.boxes
	var frames := Engine.get_process_frames()
	var clock := Time.get_ticks_msec()
	await wait(1.0)
	frames = Engine.get_process_frames() - frames
	var secs := (Time.get_ticks_msec() - clock) / 1000.0
	var once := true
	for i in still.size():
		if (still[i] as HideoutScenery.Layer).painted != int(was[i]) or int(was[i]) < 1:
			once = false
	check(once, "the towers and the room are drawn once, and not again while a second goes by")
	# Every moving depth the same number of times, since they are asked together.
	var times := (moving[0] as HideoutScenery.Layer).painted - int(was[still.size()])
	var together := times > 0
	for i in moving.size():
		if (moving[i] as HideoutScenery.Layer).painted - int(was[still.size() + i]) != times:
			together = false
	check(together, "what moves is drawn again as it does, all of it together (%d times)" % times)
	# No oftener than it says, however fast the screen is — and as often as that
	# unless the screen is slower still.
	var most := HideoutScenery.REDRAWS * secs
	check(times <= int(most) + 2 and times >= int(minf(most, float(frames)) * 0.6),
		"%.0f times a second and no oftener, on a screen drawing %d (%d in %.2f s)"
			% [HideoutScenery.REDRAWS, int(frames / secs), times, secs])
	var each := float(HideoutScenery.boxes - before) / float(maxi(times, 1))
	check(each > 100.0 and each < float(BUDGET),
		"which costs %.0f boxes a time, of the %d it may" % [each, BUDGET])

## --- what shows -------------------------------------------------------------

func _shows() -> void:
	stand(480.0)
	await wait(0.3)
	# The glass, in from its left end: the readout's last line lies over that.
	var glass := on_screen(HideoutScenery.GLASS_LEFT + 30, HideoutScenery.GLASS_TOP,
		HideoutScenery.GLASS_RIGHT - HideoutScenery.GLASS_LEFT - 30, HideoutScenery.SILL - HideoutScenery.GLASS_TOP)
	var first := await frame()
	var lights := 0
	for y in range(glass.position.y, glass.end.y, 2):
		for x in range(glass.position.x, glass.end.x, 2):
			var c := first.get_pixel(x, y)
			if maxf(c.r, maxf(c.g, c.b)) > 0.6:
				lights += 1
	check(lights > 300, "there is a city through the glass, with its lights on (%d lit pixels)" % lights)
	await wait(0.4)
	var second := await frame()
	var moved := 0
	for y in range(glass.position.y, glass.end.y, 2):
		for x in range(glass.position.x, glass.end.x, 2):
			if first.get_pixel(x, y) != second.get_pixel(x, y):
				moved += 1
	check(moved > 50, "and it is raining on it (%d pixels changed in under a second)" % moved)
	# What reaches the screen is the buffer's pixels and nothing finer.
	var origin := on_screen(0, 0, 1, 1).position
	var seen := 0
	var split := 0
	for y in range(glass.position.y, glass.end.y - S, S * 5):
		for x in range(glass.position.x, glass.end.x - S, S * 3):
			var bx := x - posmod(x - origin.x, S)
			var by := y - posmod(y - origin.y, S)
			seen += 1
			var c := second.get_pixel(bx, by)
			for dy in S:
				for dx in S:
					if second.get_pixel(bx + dx, by + dy) != c:
						split += 1
	check(seen > 500 and split == 0, "all of it in whole pixels of the buffer (%d blocks, %d split)" % [seen, split])

## Nothing of it past the room's own walls, wherever the player stands: the
## frame outside them is the frame with the scenery put away.
func _stays_in_the_room() -> void:
	var inside := on_screen(HideoutScenery.LEFT, HideoutScenery.TOP,
		HideoutScenery.RIGHT - HideoutScenery.LEFT, HideoutScenery.FLOOR + 16 - HideoutScenery.TOP)
	for spot in [60.0, 640.0, 1220.0]:
		stand(spot)
		await wait(0.5)
		var with := await frame()
		scenery.visible = false
		await wait(0.1)
		var without := await frame()
		scenery.visible = true
		var leaked := 0
		for y in with.get_height():
			for x in with.get_width():
				if inside.has_point(Vector2i(x, y)):
					continue
				if with.get_pixel(x, y) != without.get_pixel(x, y):
					leaked += 1
		check(leaked == 0, "with the player at %.0f, nothing of it shows past the room's walls (%d pixels)" % [spot, leaked])
