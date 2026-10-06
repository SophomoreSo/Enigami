extends Node
## Glass, worked out after the light by the pixel camera's glazing: clear glass
## shows what is behind it, a little tinted; a mirror shows what is in front of
## it, turned over across its nearest face to the open air, less the deeper
## into it; a back mirror shows what stands in front of it its shift off, and
## nothing of what is behind it; and what stands in front of any glass is
## neither seen through it nor shown in it.
##
## With no glass on the screen nothing is worked out, and the camera shows the
## picture as the light left it. The glass is drawn into the glazing's marks
## and nowhere else: not the picture, not the normals. What is seen through it,
## and what a mirror shows, is seen as lit.
##
## And the map creator's glass: a pane over every cell of it, clear glass and
## mirrors apart and the ground's apart from what stands behind, each mirror
## pane of the ground told where its faces to the air are, and none behind
## where ground stands in front; and clear glass is no rock to the light, where
## a mirror is.
##
## Needs a real renderer, as the light's test does: every pass is drawn on the
## graphics card and read back, and `--headless` draws nothing. A window the
## desk covers stops drawing, so a frame it did not draw is drawn here by hand
## (`tick`); with HIDE_WINDOW set the window is put away as soon as it opens.

const S := Glazing.S
const NONE := Glass.NONE
## What everything is stood on: one flat colour over the whole screen.
const GROUND := Color(0.2, 0.25, 0.3)
const RED := Color(0.9, 0.2, 0.2)
const GREEN := Color(0.2, 0.8, 0.3)
const BLUE := Color(0.2, 0.3, 0.9)
## How far a colour read back may be from the one worked out: the picture is
## read back in eight bits.
const NEAR := 0.02

var fails := 0
var pixels: PixelCamera
var glazing: Glazing
var stage: Node2D
var _drawn := false
var _hidden := false

func check(ok: bool, what: String) -> void:
	if ok:
		print("[GLASS] PASS ", what)
	else:
		fails += 1
		push_error("GLASS FAIL: " + what)

## One frame. A macOS window that something else covers is not drawn at all,
## so while that lasts the frame the loop would have drawn is drawn here.
func tick() -> void:
	await get_tree().process_frame
	if _hidden or not DisplayServer.window_can_draw():
		RenderingServer.force_draw(false)

func frames(n: int) -> void:
	for i in n:
		await tick()

## Until what has just been changed has been drawn: two frames, and then one
## seen to have been drawn — or after two seconds of none, a failure.
func settle() -> void:
	await frames(2)
	_drawn = false
	var t := 0.0
	while not _drawn:
		await tick()
		t += get_process_delta_time()
		if t > 2.0:
			check(false, "a frame is drawn (none for two seconds)")
			return

## The picture as it is shown; the picture as it came to the glazing; the
## world's colours as they were drawn; and the marks.
func shown() -> Image:
	await settle()
	return glazing.picture().get_image()

func came() -> Image:
	return pixels.lighting.picture().get_image()

func colours() -> Image:
	return pixels._view.get_texture().get_image()

func marks() -> Image:
	return glazing.marks().get_image()

## The pixel of a buffer the world point `world` is in.
func texel(world: Vector2) -> Vector2i:
	return Vector2i(((world - glazing.origin) / S).floor())

func at(img: Image, world: Vector2) -> Color:
	var t := texel(world)
	if t.x < 0 or t.y < 0 or t.x >= img.get_width() or t.y >= img.get_height():
		return Color(0, 0, 0, 0)
	return img.get_pixel(t.x, t.y)

## The middle of the pixel `across` and `down` from the one `world` is in.
func pixel_from(world: Vector2, across: int, down: int) -> Vector2:
	var t := texel(world) + Vector2i(across, down)
	return glazing.origin + (Vector2(t) + Vector2(0.5, 0.5)) * S

func near(a: Color, b: Color, by: float = NEAR) -> bool:
	return absf(a.r - b.r) <= by and absf(a.g - b.g) <= by and absf(a.b - b.b) <= by

func tinted(c: Color, by: Color) -> Color:
	return Color(c.r * by.r, c.g * by.g, c.b * by.b)

## What a mirror pixel `deep` pixels in from its face shows: what was drawn
## there, and over it `from` tinted, by as much as that depth leaves.
func mirrored(there: Color, from: Color, deep: float) -> Color:
	var shows := Glazing.MIRROR_SHOWS * (1.0 - clampf(deep / Glazing.MIRROR_DEEP, 0.0, 1.0))
	return there.lerp(tinted(from, Glazing.MIRROR_TINT), shows)

## Something drawn in code: a block of one colour.
class Painted extends Node2D:
	var paint: Callable
	func _draw() -> void:
		paint.call(self)

func block(rect: Rect2, colour: Color, z: int) -> Painted:
	var p := Painted.new()
	p.paint = func(c: CanvasItem) -> void: c.draw_rect(rect, colour)
	p.visibility_layer = PixelCamera.WORLD_LAYER
	p.z_index = z
	stage.add_child(p)
	return p

## A pane of glass, between what is behind it (under z -3) and what is in
## front of it.
func pane(rect: Rect2, kind: Glass.Kind, faces: Vector4 = Vector4(NONE, NONE, NONE, NONE)) -> Glass:
	var g := Glass.of(kind)
	g.pane(rect, faces)
	g.z_index = -3
	stage.add_child(g)
	return g

func out(things: Array) -> void:
	for t in things:
		(t as Node).queue_free()
	await frames(2)

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_hidden = OS.has_environment("HIDE_WINDOW")
	if _hidden:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	RenderingServer.frame_post_draw.connect(func() -> void: _drawn = true)
	stage = Node2D.new()
	add_child(stage)
	Arena.register(stage)
	pixels = PixelCamera.new()
	add_child(pixels)
	glazing = pixels.glazing
	var ground := block(Rect2(-64, -64, 1408, 848), GROUND, -10)
	await frames(4)
	await _no_glass()
	await _clear()
	await _in_front()
	await _a_mirror()
	await _faces()
	await _back_mirror()
	await _lit()
	await out([ground])
	await _made_map()
	print("[GLASS] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- no glass -------------------------------------------------------------------

func _no_glass() -> void:
	await settle()
	check(not glazing.working(), "with no glass on the screen nothing is worked out")
	check(pixels._image.texture.get_rid() == pixels.lighting.picture().get_rid(),
		"and the camera shows the picture as the light left it")
	var empty := Glass.of(Glass.Kind.CLEAR)
	stage.add_child(empty)
	var far_off := pane(Rect2(-900, -900, 64, 64), Glass.Kind.CLEAR)
	var hidden := pane(Rect2(100, 100, 64, 64), Glass.Kind.MIRROR)
	hidden.visible = false
	await settle()
	check(not glazing.working() and glazing.glass_shown == 0,
		"nor for glass with no pane, a pane off the screen, or one that is hidden")
	await out([empty, far_off, hidden])

## --- clear glass --------------------------------------------------------------

func _clear() -> void:
	var behind := block(Rect2(300, 200, 80, 80), GREEN, -5)
	var glass := pane(Rect2(260, 160, 160, 160), Glass.Kind.CLEAR)
	var img := await shown()
	var was := came()
	check(glazing.working() and glazing.glass_shown == 1
		and pixels._image.texture.get_rid() == glazing.picture().get_rid(),
		"clear glass on the screen is worked out, and the camera shows the picture with it in")
	var through := Vector2(341, 241)
	var bare := Vector2(271, 171)
	var past := Vector2(251, 151)
	check(near(at(img, through), tinted(GREEN, Glazing.CLEAR_TINT)),
		"what stands behind clear glass is seen through it, tinted (%s)" % at(img, through))
	check(near(at(img, bare), tinted(GROUND, Glazing.CLEAR_TINT)), "and so is the ground (%s)" % at(img, bare))
	check(near(at(img, past), at(was, past), 0.005), "and past its edge the picture is as it came")
	check(near(at(colours(), bare), GROUND, 0.005), "the glass draws nothing into the picture itself")
	var m := marks()
	check(at(m, bare).b > 200.0 and absf(at(m, bare).r) < 0.5 and absf(at(m, bare).g) < 0.5,
		"but into the marks, as clear glass (%s)" % at(m, bare))
	pixels.lighting.ambient = Color(0.6, 0.6, 0.6)
	await settle()
	var n := pixels.lighting.normals().get_image()
	check(at(n, bare).b < 2.0, "and never into the normals (%s)" % at(n, bare))
	pixels.lighting.ambient = Color.WHITE
	await out([behind, glass])

## What stands in front of the glass is in front of it.
func _in_front() -> void:
	var glass := pane(Rect2(260, 160, 160, 160), Glass.Kind.CLEAR)
	var front := block(Rect2(300, 200, 60, 60), RED, 0)
	var img := await shown()
	var was := came()
	var on_it := Vector2(321, 221)
	check(near(at(img, on_it), RED, 0.005) and near(at(img, on_it), at(was, on_it), 0.005),
		"what stands in front of clear glass is shown as it is (%s)" % at(img, on_it))
	check(at(marks(), on_it).b < 2.0, "and wipes the glass's mark out where it covers it")
	var mirror := pane(Rect2(560, 300, 160, 100), Glass.Kind.MIRROR, Vector4(0, NONE, NONE, NONE))
	var over := block(Rect2(600, 320, 40, 40), BLUE, 0)
	img = await shown()
	var on_mirror := Vector2(621, 341)
	check(near(at(img, on_mirror), BLUE, 0.005), "and so is what stands in front of a mirror (%s)" % at(img, on_mirror))
	await out([glass, front, mirror, over])

## --- mirrors ----------------------------------------------------------------------

## A mirror with the open air over it, and a block in the air: under its face
## the block, upside down.
func _a_mirror() -> void:
	var red := block(Rect2(600, 100, 64, 60), RED, 0)
	var mirror := pane(Rect2(560, 200, 160, 120), Glass.Kind.MIRROR, Vector4(0, NONE, NONE, NONE))
	var img := await shown()
	var was := came()
	var face := Vector2(631, 200)
	for deep in [0, 6, 20]:
		var here := pixel_from(face, 0, deep)
		var there := pixel_from(face, 0, -1 - deep)
		check(near(at(img, here), mirrored(at(was, here), at(was, there), float(deep))),
			"%d pixels under its face a mirror shows what is %d over it (%s for %s)" % [deep, deep + 1, at(img, here), at(was, there)])
	var into := pixel_from(face, 0, 24)
	check(near(at(img, into), mirrored(at(was, into), RED, 24.0)), "the block over it, upside down (%s)" % at(img, into))
	var m := marks()
	var six := at(m, pixel_from(face, 0, 6))
	check(is_equal_approx(six.g, -13.0 * 16.0) and is_zero_approx(six.r) and six.b < -200.0,
		"its mark is a mirror's, and the way to what it shows: 13 pixels up from 6 under the face (%s)" % six)
	var deepest := pixel_from(face, 0, int(Glazing.MIRROR_DEEP) + 2)
	check(near(at(img, deepest), at(was, deepest), 0.005), "and past MIRROR_DEEP it shows nothing")
	await out([red, mirror])
	# One whose face is near the top of the picture: what it would show is off
	# the picture, and it shows nothing.
	var high := pane(Rect2(800, 10, 120, 80), Glass.Kind.MIRROR, Vector4(0, NONE, NONE, NONE))
	img = await shown()
	was = came()
	var low := pixel_from(Vector2(860, 10), 0, 20)
	check(near(at(img, low), at(was, low), 0.005), "a mirror shows nothing of what is off the picture")
	await out([high])

## Every way a mirror can face, and the nearest face winning.
func _faces() -> void:
	# A wall of it, its face to the left, and a block beside it.
	var blue := block(Rect2(860, 400, 40, 100), BLUE, 0)
	var wall := pane(Rect2(940, 380, 120, 140), Glass.Kind.MIRROR, Vector4(NONE, NONE, 0, NONE))
	# Its face to the right, and to the bottom.
	var left_of := block(Rect2(180, 420, 40, 60), GREEN, 0)
	var right := pane(Rect2(60, 400, 100, 100), Glass.Kind.MIRROR, Vector4(NONE, NONE, NONE, 0))
	var under := block(Rect2(460, 560, 80, 40), RED, 0)
	var ceiling := pane(Rect2(440, 420, 120, 100), Glass.Kind.MIRROR, Vector4(NONE, 0, NONE, NONE))
	var img := await shown()
	var was := came()
	var at_wall := pixel_from(Vector2(940, 450), 25, 0)
	check(near(at(img, at_wall), mirrored(at(was, at_wall), at(was, pixel_from(Vector2(940, 450), -26, 0)), 25.0))
		and near(at(was, pixel_from(Vector2(940, 450), -26, 0)), BLUE, 0.005),
		"a mirror facing left shows what is beside it, turned round (%s)" % at(img, at_wall))
	var at_right := pixel_from(Vector2(160, 450), -1 - 12, 0)
	check(near(at(img, at_right), mirrored(at(was, at_right), at(was, pixel_from(Vector2(160, 450), 12, 0)), 12.0))
		and near(at(was, pixel_from(Vector2(160, 450), 12, 0)), GREEN, 0.005),
		"one facing right, the same the other way (%s)" % at(img, at_right))
	var at_ceiling := pixel_from(Vector2(500, 520), 0, -1 - 25)
	check(near(at(img, at_ceiling), mirrored(at(was, at_ceiling), at(was, pixel_from(Vector2(500, 520), 0, 25)), 25.0))
		and near(at(was, pixel_from(Vector2(500, 520), 0, 25)), RED, 0.005),
		"and one facing down, what is under it (%s)" % at(img, at_ceiling))
	await out([blue, wall, left_of, right, under, ceiling])
	# A block of mirror with the air over it and to its left: each pixel shows
	# the world across whichever of the two is nearer.
	var corner := pane(Rect2(700, 500, 120, 120), Glass.Kind.MIRROR, Vector4(0, NONE, 0, NONE))
	await settle()
	var m := marks()
	var nearer_top := pixel_from(Vector2(700, 500), 20, 3)
	var nearer_side := pixel_from(Vector2(700, 500), 3, 20)
	check(is_equal_approx(at(m, nearer_top).g, -7.0 * 16.0) and is_zero_approx(at(m, nearer_top).r),
		"a pixel of a block of mirror nearer its top shows across the top (%s)" % at(m, nearer_top))
	check(is_equal_approx(at(m, nearer_side).r, -7.0 * 16.0) and is_zero_approx(at(m, nearer_side).g),
		"and one nearer its side, across the side (%s)" % at(m, nearer_side))
	# A face past the pane's own edge: the pane is the lower part of a block
	# of mirror whose face is 8 pixels over it.
	var lower := pane(Rect2(900, 100, 80, 60), Glass.Kind.MIRROR, Vector4(8, NONE, NONE, NONE))
	await settle()
	m = marks()
	check(is_equal_approx(at(m, pixel_from(Vector2(900, 100), 4, 0)).g, -17.0 * 16.0),
		"the face of a block of it can lie past a pane's edge: its first row then shows across it from 8 deep (%s)" % at(m, pixel_from(Vector2(900, 100), 4, 0)))
	await out([corner, lower])

## A mirror on the back wall, facing the eye: what stands in front of it shows
## in it its shift off — over what it was drawn as, as clear glass shows that —
## and what is behind it does not.
func _back_mirror() -> void:
	var behind := block(Rect2(860, 380, 60, 60), GREEN, -5)
	var mirror := Glass.of(Glass.Kind.BACK_MIRROR)
	mirror.shift = Vector2i(12, -6)
	mirror.pane(Rect2(800, 300, 240, 220))
	mirror.z_index = -3
	stage.add_child(mirror)
	var front := block(Rect2(880, 420, 40, 60), RED, 0)
	var img := await shown()
	var was := came()
	var k := Glazing.BACK_SHOWS
	# The right edge of the block in front, and where it shows: 12 pixels right
	# of it and 6 up, past the block itself.
	var edge := Vector2(919, 441)
	var shows_at := pixel_from(edge, 12, -6)
	var expect := tinted(GROUND, Glazing.CLEAR_TINT) * (1.0 - k) + tinted(RED, Glazing.MIRROR_TINT) * k
	check(near(at(img, shows_at), Color(expect.r, expect.g, expect.b)),
		"a back mirror shows what stands in front of it its shift off (%s)" % at(img, shows_at))
	check(near(at(img, edge), RED, 0.005), "and what stands in front of it is shown as it is")
	var m := marks()
	check(at(m, shows_at).b > 200.0 and is_equal_approx(at(m, shows_at).r, -12.0 * 16.0) and is_equal_approx(at(m, shows_at).g, 6.0 * 16.0),
		"its mark faces the eye, with the way to what it shows (%s)" % at(m, shows_at))
	# Where what it would show is behind it: the green block, under the pane.
	var over_green := pixel_from(Vector2(871, 391), 12, -6)
	check(near(at(img, over_green), tinted(at(was, over_green), Glazing.CLEAR_TINT)),
		"what is behind it is not in front of it, and is not shown (%s)" % at(img, over_green))
	var on_green := Vector2(871, 391)
	check(near(at(img, on_green), tinted(GREEN, Glazing.CLEAR_TINT)),
		"and it is seen through, as clear glass sees it, where nothing shows over it (%s)" % at(img, on_green))
	await out([behind, mirror, front])

## --- with the light ---------------------------------------------------------------

func _lit() -> void:
	var glass := pane(Rect2(260, 160, 160, 160), Glass.Kind.CLEAR)
	var red := block(Rect2(600, 100, 64, 60), RED, 0)
	var mirror := pane(Rect2(560, 200, 160, 120), Glass.Kind.MIRROR, Vector4(0, NONE, NONE, NONE))
	pixels.lighting.ambient = Color(0.5, 0.5, 0.5)
	var img := await shown()
	var was := came()
	var bare := Vector2(271, 171)
	check(pixels.lighting.working() and near(at(was, bare), Color(GROUND.r * 0.5, GROUND.g * 0.5, GROUND.b * 0.5)),
		"with the room darker the glazing is handed the lit picture")
	check(near(at(img, bare), tinted(Color(GROUND.r * 0.5, GROUND.g * 0.5, GROUND.b * 0.5), Glazing.CLEAR_TINT)),
		"and what is seen through clear glass is seen lit (%s)" % at(img, bare))
	var face := Vector2(631, 200)
	var here := pixel_from(face, 0, 25)
	check(near(at(img, here), mirrored(at(was, here), Color(RED.r * 0.5, RED.g * 0.5, RED.b * 0.5), 25.0)),
		"and what a mirror shows, shown lit (%s)" % at(img, here))
	pixels.lighting.ambient = Color.WHITE
	await out([glass, red, mirror])

## --- the map creator's glass -----------------------------------------------------

func _made_map() -> void:
	var plan := PackedStringArray()
	var back := PackedStringArray()
	for y in Room.H:
		var row := ""
		var behind := ""
		for x in Room.W:
			var mark := MadeRoom.OPEN
			if y >= 20:
				mark = "%"
			if y == 20 and x >= 10 and x < 20:
				mark = "@"
			if x == 25 and y >= 15 and y < 20:
				mark = "o"
			if x == 30 and y >= 15 and y < 20:
				mark = "@"
			row += mark
			var hung := MadeRoom.OPEN
			if x >= 4 and x < 7 and y >= 8 and y < 11:
				hung = "o"
			# A mirror on the back wall, its foot behind the floor.
			if x >= 34 and x < 37 and y >= 15 and y < 21:
				hung = "@"
			behind += hung
		plan.append(row)
		back.append(behind)
	var room := MadeRoom.new()
	room.tileset = "grove"
	room.plan = plan
	room.back = back
	stage.add_child(room)
	room.stand()
	await frames(4)
	var view := Views.of(room) as MadeRoomView
	check(view != null and view.glass.size() == 4, "a made map's glass stands in it, clear and mirror apart, the ground's and what stands behind")
	if view == null or view.glass.size() != 4:
		room.queue_free()
		return
	var of := func(kind: Glass.Kind, z: int) -> Glass:
		for g in view.glass:
			if g.kind == kind and g.z_index == z:
				return g
		return null
	var clear: Glass = of.call(Glass.Kind.CLEAR, -7)
	var mirror: Glass = of.call(Glass.Kind.MIRROR, -7)
	var window: Glass = of.call(Glass.Kind.CLEAR, -8)
	var looking: Glass = of.call(Glass.Kind.BACK_MIRROR, -8)
	check(clear != null and mirror != null and window != null and looking != null,
		"the ground's in front of what stands behind, and a mirror behind is one that faces the eye")
	if clear == null or mirror == null or window == null or looking == null:
		room.queue_free()
		return
	check(clear.panes() == 5 and mirror.panes() == 15, "a pane over every cell of the ground's (%d clear, %d mirror)" % [clear.panes(), mirror.panes()])
	check(window.panes() == 9 and looking.panes() == 15,
		"and of what stands behind, but where ground stands in front of it (%d clear, %d mirror)" % [window.panes(), looking.panes()])
	check(MapTiles.glass_pane(view.cells, 35, 17, true)[1] == Vector4(NONE, NONE, NONE, NONE) and looking.shift == Glazing.BACK_SHIFT,
		"a pane of it has no faces, and shows what stands in front of it the glazing's way off")
	var floor_pane := MapTiles.glass_pane(view.cells, 14, 20)
	check(floor_pane[1] == Vector4(1, NONE, NONE, NONE),
		"a mirror floor's face is the top of it, over the frame, and nothing else (%s)" % floor_pane[1])
	var pillar := MapTiles.glass_pane(view.cells, 30, 17)
	check(pillar[1] == Vector4(2 * MapTiles.C, NONE, 1, 1),
		"a pillar of it faces up from its top, and either way from its sides (%s)" % pillar[1])
	await settle()
	check(glazing.working() and glazing.glass_shown == 4, "and the glazing works it out")
	var m := marks()
	var on_floor := Vector2(14.5 * Room.CELL, 20.5 * Room.CELL)
	check(at(m, on_floor).b < -200.0, "a pane of the floor is a mirror in the marks")
	check(at(m, Vector2(25.5 * Room.CELL, 17.5 * Room.CELL)).b > 200.0, "and one of the clear pillar clear glass")
	var on_back := at(m, Vector2(35.5 * Room.CELL, 17.5 * Room.CELL))
	check(on_back.b > 200.0 and is_equal_approx(on_back.r, -Glazing.BACK_SHIFT.x * 16.0) and is_equal_approx(on_back.g, -Glazing.BACK_SHIFT.y * 16.0),
		"and one of the mirror behind a back mirror (%s)" % on_back)
	# The rock's edges, as the light has them: the mirror pillar's sides are
	# edges, and the clear pillar's are not.
	var along := func(x: float) -> bool:
		for line: Array in view.air_lines():
			var from: Vector2 = line[0]
			var to: Vector2 = line[1]
			if is_equal_approx(from.x, x) and is_equal_approx(to.x, x) and minf(from.y, to.y) <= 16.0 * Room.CELL and maxf(from.y, to.y) >= 18.0 * Room.CELL:
				return true
		return false
	check(along.call(30.0 * Room.CELL) and along.call(31.0 * Room.CELL), "a mirror is rock to the light, and throws a shadow")
	check(not along.call(25.0 * Room.CELL) and not along.call(26.0 * Room.CELL), "clear glass is not, and throws none")
	room.queue_free()
	await frames(2)
