extends Node
## The screen takes the display's shape. The game is laid out in 1280x720 and
## drawn at least that big, but `expand` stretch gives a display longer than
## 16:9 more width and a squarer one more height, where `keep` used to put
## black bars either side of a phone. So this checks what each part of the game
## does with the room it is given, on a window the shape of a long phone and on
## one the shape of a tablet:
##
##   * the world fills it: the rock round the bench's room runs out to every
##     edge of the screen, read back off the frame itself;
##   * the title stands its design in the middle and has copper out to the edges;
##   * the assembly screen stands its board and palette in the middle and leaves
##     CLOSE in the corner;
##   * the pause menu, built once at boot, covers the screen it is opened on.
##
## Where the console's controls go on each shape is `touch_pad_test`'s.
##
## Neither window is 1:1 with the screen, so the frame read back is in window
## pixels and every point on the screen is carried there through the window.

const GameScript := preload("res://app/game.gd")
const DESIGN := Vector2(1280, 720)
## A phone a little longer than the one the black bars were reported on, and a
## 4:3 tablet.
const LONG := Vector2i(1480, 640)
const SQUARE := Vector2i(1152, 864)
## Brighter than this in some channel is rock; the dark past the world, and the
## room's own ground, are not.
const ROCK := 0.12
## Further than this from the title's ground in some channel is copper.
const COPPER := 0.05
## How far the title's own copper runs past the design: traces set down up to 40
## outside it, and a leg running a grid step further (`TitleScreen._grow_trace`).
const OVERHANG := 48.0

var fails := 0
var game: Node

func check(ok: bool, what: String) -> void:
	if ok:
		print("[FIT] PASS ", what)
	else:
		fails += 1
		push_error("FIT FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func screen() -> Vector2:
	return get_viewport().get_visible_rect().size

## The frame as it reached the window.
func frame() -> Image:
	await frames(4)
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()

## The colour at `at` on the screen, found in a frame of the window.
func colour(im: Image, at: Vector2) -> Color:
	var p := Vector2i((get_window().get_final_transform() * at).floor())
	return im.get_pixelv(p.clamp(Vector2i.ZERO, im.get_size() - Vector2i.ONE))

## How bright the few pixels round `at` get, in their brightest channel. A point
## can land on the seam between two tiles, where both their edges darken the
## rock to nearly the room's own ground, and still find the rock either side;
## a screen with nothing drawn there is dark all the way across.
func brightest(im: Image, at: Vector2) -> float:
	var p := Vector2i((get_window().get_final_transform() * at).floor())
	var most := 0.0
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var q := (p + Vector2i(dx, dy)).clamp(Vector2i.ZERO, im.get_size() - Vector2i.ONE)
			var c := im.get_pixelv(q)
			most = maxf(most, maxf(c.r, maxf(c.g, c.b)))
	return most

func _ready() -> void:
	var was_size := DisplayServer.window_get_size()
	var was_mode := Touch.mode
	Touch.set_mode(Touch.OFF)
	GameState.reset_profile()
	_the_setting()
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(10)
	for shape: Vector2i in [LONG, SQUARE]:
		# Through the Window node, not the display server: the node is what sizes
		# the viewport, and on X11 without a window manager (CI's Xvfb) it never
		# hears of a size set past it, so the design stayed 1280x720 there.
		get_window().size = shape
		await frames(8)
		if not _the_shape(shape):
			continue
		await _the_title()
		game.goto_sandbox()
		await frames(20)
		await _the_world()
		await _the_workbench()
		await _the_pause()
		game.goto_title()
		await frames(10)
	Touch.set_mode(was_mode)
	get_window().size = was_size
	print("[FIT] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## What all of it rests on, and what an editor saving the project from a copy
## older than it would quietly take away.
func _the_setting() -> void:
	var root := get_tree().root
	check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			and root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND,
		"the screen scales canvas items and takes the display's shape")

## The screen on a window of `shape`: the design grown in whichever direction
## the window has more of, never bars.
func _the_shape(shape: Vector2i) -> bool:
	var got := DisplayServer.window_get_size()
	if got.x * 9 == got.y * 16:
		print("[FIT] skip %s: the window came out 16:9 (%s), which is the design" % [shape, got])
		return false
	var s := screen()
	var long := got.x * 9 > got.y * 16
	check((is_equal_approx(s.y, DESIGN.y) and s.x > DESIGN.x + 1.0) if long
			else (is_equal_approx(s.x, DESIGN.x) and s.y > DESIGN.y + 1.0),
		"a %dx%d window is the design grown %s (%s)"
			% [got.x, got.y, "across" if long else "down", str(s)])
	return true

func _the_title() -> void:
	var t := game.current as TitleScreen
	check(t != null, "the title is up")
	if t == null:
		return
	var s := screen()
	var mid := (s - DESIGN) * 0.5
	check(t._stage.position.distance_to(mid) <= float(UiKit.PIXEL),
		"the title's design stands in the middle of the screen (%s, the middle %s)"
			% [str(t._stage.position), str(mid)])
	var menu := t._menu_root.get_global_rect()
	check(absf(menu.get_center().x - s.x * 0.5) <= float(UiKit.PIXEL),
		"and so does its menu (%.0f, the middle %.0f)" % [menu.get_center().x, s.x * 0.5])
	# Past the design, where the board used to stop — and past the 48 its own
	# copper already hangs over the design's edge, so what is found is the board
	# grown out there for this: the sides of it on a long screen, the top on a
	# square one. Not the bottom, which sinks into black on purpose under the menu.
	var strips: Array = []
	var over := OVERHANG + 8.0
	if mid.x >= over + 16.0:
		strips.append(Rect2(0, 0, mid.x - over, TitleScreen.SETTLE_TOP))
		strips.append(Rect2(s.x - mid.x + over, 0, mid.x - over, TitleScreen.SETTLE_TOP))
	if mid.y >= over + 16.0:
		strips.append(Rect2(0, 0, s.x, mid.y - over))
	check(not strips.is_empty(), "the screen shows past the design's own copper somewhere (%s)" % str(mid))
	var im: Image = await frame()
	var ground := TitleScreen.GROUND
	for strip: Rect2 in strips:
		var lit := 0
		var seen := 0
		var y := strip.position.y + 1.0
		while y < strip.end.y:
			var x := strip.position.x + 1.0
			while x < strip.end.x:
				var c := colour(im, Vector2(x, y))
				seen += 1
				if maxf(absf(c.r - ground.r), maxf(absf(c.g - ground.g), absf(c.b - ground.b))) > COPPER:
					lit += 1
				x += 3.0
			y += 3.0
		check(seen > 0 and float(lit) / float(seen) > 0.01,
			"the title's copper runs on past the design, in %s (%d of %d points)"
				% [str(strip), lit, seen])

func _the_world() -> void:
	var sb := game.current as Sandbox
	check(sb != null, "the bench is up")
	if sb == null:
		return
	var s := screen()
	# Down both sides and along the top and the bottom, clear of the HUD's
	# corner and the drawer's tab on the left edge (264 to 328).
	var points: Array = []
	for y in [180.0, 400.0, 520.0, s.y - 70.0]:
		points.append(Vector2(1.0, y))
	for k in [0.2, 0.4, 0.6, 0.8]:
		points.append(Vector2(s.x - 2.0, s.y * k))
	for k in [0.35, 0.5, 0.65, 0.9]:
		points.append(Vector2(s.x * k, 1.0))
		points.append(Vector2(s.x * k, s.y - 2.0))
	var im: Image = await frame()
	var bare: Array = []
	for at: Vector2 in points:
		if brightest(im, at) < ROCK:
			bare.append("%s %s" % [str(at), colour(im, at).to_html(false)])
	check(bare.is_empty(), "the bench's rock runs out to every edge of the screen (bare: %s)" % str(bare))

func _the_workbench() -> void:
	var sb := game.current as Sandbox
	if sb == null:
		return
	sb.set_editing(true)
	await frames(4)
	var ed: SkillEditor = (Views.of(sb) as SandboxView).editor
	var s := screen()
	var left := ed._cell_rect(Vector2i.ZERO).position.x - 10.0
	var right := s.x - ed._pal_panel().end.x
	check(absf(left - right) <= float(UiKit.PIXEL) * 2.0,
		"the assembly screen stands in the middle (%.0f clear on the left, %.0f on the right)"
			% [left, right])
	check(is_equal_approx(ed._close_rect().end.x, s.x - 16.0),
		"and CLOSE stays in the corner (%.0f of %.0f)" % [ed._close_rect().end.x, s.x])
	sb.set_editing(false)
	await frames(4)

func _the_pause() -> void:
	game._pause()
	await frames(4)
	check(game.pause_menu.size.is_equal_approx(screen()),
		"the pause menu, built at boot, covers the screen it is opened on (%s of %s)"
			% [str(game.pause_menu.size), str(screen())])
	game._unpause()
	await frames(4)
