extends Node
## The hideout's scenery (`HideoutScenery`), in every look it has
## (`HideoutThemes`): what is out past the room's wall and the room's own
## fittings, drawn in code a pixel of the buffer at a time.
##
## What every look is held to. The room is dressed in it: it stands in the
## room's own view, in front of the tiles and behind everything that hangs,
## grows or moves, and putting another on takes the last one off. It was laid
## out for the room it is in — its edges are the room's, and what it stands at
## each station stands on the floor under that station, with the station's sign
## hung clear over it, in the look's own colours. Its depths slide by whole
## pixels of the buffer as the player walks the room, the other way from the
## player, and what stands in the room does not slide at all; and none of it,
## at either end of the room, shows past the room's own walls. A station's
## fittings light when the player is at one that would answer, and the gate is
## lit in the colour of whether it would. It moves. And a frame of it costs
## what moves and no more: what stands still is drawn once.
##
## And what the city is held to besides, being the look with things in it to
## read: the same city every time, with its signs clear of the posts between
## the panes however far their depth slides, its lights on, and the rain on it.
##
## Needs a real renderer: what shows is read off the frame.

const GameScript := preload("res://app/game.gd")
const S := HideoutScenery.S
## What drawing everything that moves may cost, in boxes.
const BUDGET := 1000

var game: Node
var world: HideoutWorld
var view: HideoutWorldView
var scenery: HideoutScenery
var bot: ComputerHands
## The look being tried, which every line says first.
var look := ""
var fails := 0
var _drawn := false

func check(ok: bool, what: String) -> void:
	if ok:
		print("[SCENERY] PASS %s: %s" % [look, what])
	else:
		fails += 1
		push_error("SCENERY FAIL: %s: %s" % [look, what])

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

## Every depth of the look on, back to front within each kind.
func depths() -> Array:
	var out: Array = []
	out.append_array(scenery._still)
	out.append_array(scenery._moving)
	return out

func _ready() -> void:
	RenderingServer.frame_post_draw.connect(func() -> void: _drawn = true)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	GameState.reset_profile()
	# Whatever the desk's own pick is, this starts from the look a room wears
	# until somebody picks another, and keeps none of what it tries on.
	HideoutThemes.pick(HideoutThemes.DEFAULT, false)
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await wait(0.2)
	game.goto_hideout()
	world = game.current
	await settle(func() -> bool: return (Views.of(world) as HideoutWorldView).scenery != null)
	view = Views.of(world)
	# The computer's hands, so the crosshair stays where it is put and nobody's
	# mouse moves anything while frames are being compared.
	bot = ComputerHands.new()
	world.player.input.add(bot)
	bot.point_at(Vector2(640, 700))

	look = "the looks"
	check(HideoutThemes.LOOKS.has(HideoutThemes.DEFAULT) and HideoutThemes.LOOKS.size() > 1,
		"there is more than one, and the one a room starts in is among them (%s)" % str(HideoutThemes.LOOKS))
	var kinds: Array = []
	for id: String in HideoutThemes.LOOKS:
		var made := HideoutThemes.make(id)
		if made.look == id and not kinds.has(made.get_script()):
			kinds.append(made.get_script())
		made.free()
	check(kinds.size() == HideoutThemes.LOOKS.size(), "each is a scenery of its own (%d of %d)"
		% [kinds.size(), HideoutThemes.LOOKS.size()])
	var odd := HideoutThemes.make("no such look")
	check(odd.look == HideoutThemes.DEFAULT, "and a look nobody has heard of is the one a room starts in")
	odd.free()

	for id: String in HideoutThemes.LOOKS:
		look = id
		await _wear(id)
		_dressed()
		_laid_out()
		await _signs()
		await _slides()
		await _lights()
		await _cost()
		await _shows()
		await _stays_in_the_room()
		if scenery is HideoutCity:
			_clear_of_the_posts()
			_same_city()
			await _the_city_slides()
			await _the_city_shows()

	HideoutThemes.pick(HideoutThemes.DEFAULT, false)
	print("[SCENERY] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- putting it on ----------------------------------------------------------

func _wear(id: String) -> void:
	var before := view.scenery
	HideoutThemes.pick(id, false)
	scenery = view.scenery
	check(scenery != null and scenery.look == id, "the room is dressed in it the moment it is picked")
	if before != scenery:
		check(not is_instance_valid(before) or before.is_queued_for_deletion() or not before.is_inside_tree(),
			"and the look it had on is taken off")
	stand(480.0)
	gate().open = true
	await wait(0.5)
	var worn := 0
	for n in (Views.of(world.room) as RoomView).get_children():
		if n is HideoutScenery:
			worn += 1
	check(worn == 1, "one look at a time (%d on)" % worn)

func gate() -> Station:
	return world.stations["gate"]

## --- where it stands --------------------------------------------------------

func _dressed() -> void:
	var room_view := Views.of(world.room) as RoomView
	check(scenery.get_parent() == room_view, "it stands in the room's own view")
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
	check(not scenery._still.is_empty() and not scenery._moving.is_empty(),
		"it has depths that stand still and depths that move (%d and %d)"
			% [scenery._still.size(), scenery._moving.size()])

func _laid_out() -> void:
	var room := world.room
	check(HideoutScenery.LEFT * S == Room.CELL and HideoutScenery.RIGHT * S == (Room.W - 1) * Room.CELL
			and HideoutScenery.TOP * S == Room.CELL,
		"it was laid out for a room this size: its walls and ceiling are the room's")
	var open_all_the_way := true
	@warning_ignore("integer_division")
	var floor_row := HideoutScenery.FLOOR * S / Room.CELL
	for x in range(1, Room.W - 1):
		for y in range(1, floor_row):
			if room.is_solid(x, y):
				open_all_the_way = false
		if not room.is_solid(x, floor_row):
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

## The signs over the stations are the view's, and hang in the look's colours.
func _signs() -> void:
	stand(480.0)
	await wait(0.3)
	var im := await frame()
	var onto := get_viewport().get_final_transform() * get_viewport().get_canvas_transform() * view.global_transform
	var ground := true
	var edged := true
	for id in world.stations:
		var plate := view._plate(world.stations[id] as Station)
		# In from the corner for the plate itself, and on its edge for the line
		# round it, which is a pixel of the buffer wide.
		var inside: Vector2 = onto * (plate.position + Vector2(6.0, 6.0))
		var edge: Vector2 = onto * (plate.position + Vector2(0.0, plate.size.y * 0.5))
		if not _near(im.get_pixelv(Vector2i(inside)), scenery.plate):
			ground = false
		if not _near(im.get_pixelv(Vector2i(edge)), scenery.ink):
			edged = false
	check(ground and edged, "the signs over the stations hang in its colours (plate %s, written in %s)"
		% [scenery.plate.to_html(false), scenery.ink.to_html(false)])
	check(scenery.ink_lit != scenery.ink and scenery.ink_shut != scenery.ink,
		"with one to be lit in and one for a station that is shut")

func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02

## --- what it does -----------------------------------------------------------

func _slides() -> void:
	var all := depths()
	# A depth is put where it belongs every frame, so a few frames after the
	# player is stood somewhere it is there — by the clock, a slow screen's few.
	stand(60.0)
	await wait(0.3)
	var left: Array = all.map(func(l: Node2D) -> float: return l.position.x)
	stand(1220.0)
	await wait(0.3)
	var right: Array = all.map(func(l: Node2D) -> float: return l.position.x)
	check(float(left.max()) > 0.0 and float(left.min()) >= 0.0,
		"at the left wall what is far off has slid right, and nothing left (%s)" % str(left))
	check(float(right.min()) < 0.0 and float(right.max()) <= 0.0, "and at the right wall, left (%s)" % str(right))
	var whole := true
	var mirrored := true
	for i in left.size():
		if fmod(float(left[i]), float(S)) != 0.0 or fmod(float(right[i]), float(S)) != 0.0:
			whole = false
		if float(left[i]) != -float(right[i]):
			mirrored = false
	check(whole, "by whole pixels of the buffer")
	check(mirrored, "as far one way as the other")
	# What stands in the room is drawn last, and stays where the room is.
	var still_in_front: HideoutScenery.Layer = scenery._still[scenery._still.size() - 1]
	var moving_in_front: HideoutScenery.Layer = scenery._moving[scenery._moving.size() - 1]
	check(still_in_front.position == Vector2.ZERO and moving_in_front.position == Vector2.ZERO,
		"what stands in the room does not slide at all")
	var up := true
	for l: Node2D in all:
		if l.position.y != 0.0:
			up = false
	check(up, "and nothing slides up or down")
	stand(640.0)
	await settle(func() -> bool: return _furthest(all) == 0.0)
	check(_furthest(all) == 0.0, "and from the middle of the room it is all square")

## How far the depth that has slid furthest has slid, either way.
func _furthest(all: Array) -> float:
	var most := 0.0
	for l: Node2D in all:
		if absf(l.position.x) > absf(most):
			most = l.position.x
	return most

func _lights() -> void:
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
	gate().open = false
	stand_at("gate")
	await wait(0.6)
	check(not scenery._gate_open() and float(scenery._lit["gate"]) == 0.0,
		"a gate that would not open lights for nobody (%.2f)" % float(scenery._lit["gate"]))
	gate().open = true
	check(await settle(func() -> bool: return float(scenery._lit["gate"]) == 1.0), "and lights again once it would")
	# What it is lit in, read with nobody standing in front of it.
	stand(480.0)
	await wait(0.3)
	var open := await _gate_lights()
	gate().open = false
	var shut := await _gate_lights()
	gate().open = true
	check(shut.x - open.x > 20.0 and open.y - shut.y > 20.0,
		"the gate is lit red while it is shut and green once it is open (%.0f more red pixels shut, %.0f more green open)"
			% [shut.x - open.x, open.y - shut.y])

## How lit the stations other than `id` are, all told.
func _lit_elsewhere(id: String) -> float:
	var sum := 0.0
	for other in scenery._lit:
		if other != id:
			sum += float(scenery._lit[other])
	return sum

## How much red light the gate shows and how much green, as `x` and `y`: the
## pixels over the top of it, clear of what grows at its foot, that are bright,
## strongly coloured and plainly the one hue or the other, counted over three
## seconds of it — a shut gate's lamps come and go slowly, and that is one
## whole breath of them. By hue, because a look is made of colours of its own
## — brass is bright and warm and no lamp, a crystal is blue, moss is green
## whether the gate is open or not — and what is asked is how the count
## changes.
func _gate_lights() -> Vector2:
	var g: Vector2i = scenery._at["gate"]
	var ring := on_screen(g.x - 32, g.y - HideoutScenery.TALLEST - 2, 64, 44)
	var lights := Vector2.ZERO
	for again in 7:
		await wait(0.45)
		var im := await frame()
		for y in range(ring.position.y, ring.end.y, 2):
			for x in range(ring.position.x, ring.end.x, 2):
				var c := im.get_pixel(x, y)
				if c.v < 0.45 or c.s < 0.5:
					continue
				if c.h < 0.035 or c.h > 0.96:
					lights.x += 1.0
				elif c.h > 0.25 and c.h < 0.47:
					lights.y += 1.0
	return lights

func _cost() -> void:
	stand(480.0)
	await wait(0.3)
	var still: Array = scenery._still
	var moving: Array = scenery._moving
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
	check(once, "what stands still is drawn once, and not again while a second goes by")
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

## The stretch of the room over the stations' signs and clear of the readout:
## nothing in it but the look, and whatever the room hangs.
func _over_the_signs() -> Rect2i:
	return on_screen(170, 60, 440, 160)

func _shows() -> void:
	stand(480.0)
	await wait(0.3)
	var wall := _over_the_signs()
	var first := await frame()
	var tones := {}
	for y in range(wall.position.y, wall.end.y, 4):
		for x in range(wall.position.x, wall.end.x, 4):
			tones[first.get_pixel(x, y).to_rgba32()] = true
	check(tones.size() > 40, "there is a picture of something there (%d colours in it)" % tones.size())
	await wait(0.4)
	var second := await frame()
	var moved := 0
	for y in range(wall.position.y, wall.end.y, 2):
		for x in range(wall.position.x, wall.end.x, 2):
			if first.get_pixel(x, y) != second.get_pixel(x, y):
				moved += 1
	check(moved > 20, "and it moves (%d pixels changed in under a second)" % moved)
	# What reaches the screen is the buffer's pixels and nothing finer.
	var origin := on_screen(0, 0, 1, 1).position
	var seen := 0
	var split := 0
	for y in range(wall.position.y, wall.end.y - S, S * 5):
		for x in range(wall.position.x, wall.end.x - S, S * 3):
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
		HideoutScenery.RIGHT - HideoutScenery.LEFT, HideoutScenery.UNDER - HideoutScenery.TOP)
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

## --- the city, besides ----------------------------------------------------------

## Everything out in the city that is there to be read, however far it slides.
func _clear_of_the_posts() -> void:
	check(HideoutCity.GLASS_LEFT - HideoutCity.SLIDE * 2 >= HideoutScenery.LEFT,
		"a depth slid all the way over still ends behind the left pillar")
	check(HideoutCity.GLASS_RIGHT + HideoutCity.SLIDE * 2 <= HideoutScenery.RIGHT,
		"and behind the gate's bay on the right")
	for board in HideoutCity.SIGNS + HideoutCity.SCREENS:
		var at: Vector2i = board["at"]
		var size: Vector2i = board["size"]
		var from := at.x - HideoutCity.SLIDE
		var to := at.x + size.x + HideoutCity.SLIDE
		var clear := from >= HideoutCity.GLASS_LEFT and to <= HideoutCity.GLASS_RIGHT
		for post: int in HideoutCity.POSTS:
			if from < post + 3 and to > post:
				clear = false
		check(clear and at.y >= HideoutCity.GLASS_TOP and at.y + size.y <= HideoutCity.SILL,
			"%s stays in one pane of the glass, clear of the posts (%d to %d)"
				% [String(board.get("says", "a screen")), from, to])

func _same_city() -> void:
	var city := scenery as HideoutCity
	var again := HideoutCity.new()
	add_child(again)
	check(str(again._far_towers) == str(city._far_towers) and str(again._mid_towers) == str(city._mid_towers)
			and str(again._near_towers) == str(city._near_towers) and not city._mid_towers.is_empty(),
		"the city is the same city every time (%d, %d and %d towers)"
			% [city._far_towers.size(), city._mid_towers.size(), city._near_towers.size()])
	again.free()

func _the_city_slides() -> void:
	var city := scenery as HideoutCity
	var most := float(HideoutCity.SLIDE * S)
	stand(60.0)
	await settle(func() -> bool: return city._near.position.x == most)
	var left := [city._far.position.x, city._mid.position.x, city._near.position.x]
	check(left[2] == most and left[0] > 0.0 and left[0] < left[1] and left[1] < left[2],
		"at the left wall the nearest towers have slid furthest (%s)" % str(left))
	stand(1220.0)
	await settle(func() -> bool: return city._near.position.x == -most)
	var right := [city._far.position.x, city._mid.position.x, city._near.position.x]
	check(right[2] == -most and right[0] < 0.0 and right[0] > right[1] and right[1] > right[2],
		"and at the right wall (%s)" % str(right))
	check(city._signs.position == city._near.position and city._traffic.position == city._mid.position
			and city._rain.position == Vector2.ZERO and city._wall.position == Vector2.ZERO,
		"what moves out there slides with its depth; the rain and the room do not slide at all")
	stand(640.0)
	await settle(func() -> bool: return city._near.position.x == 0.0)

func _the_city_shows() -> void:
	stand(480.0)
	await wait(0.3)
	# The glass, in from its left end: the readout's last line lies over that.
	var glass := on_screen(HideoutCity.GLASS_LEFT + 30, HideoutCity.GLASS_TOP,
		HideoutCity.GLASS_RIGHT - HideoutCity.GLASS_LEFT - 30, HideoutCity.SILL - HideoutCity.GLASS_TOP)
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
