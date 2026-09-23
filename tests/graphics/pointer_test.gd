extends Node2D
## The mouse pointer the game draws for itself.
##
## The game does not drive the system pointer. It drove it once, to serve a
## sensitivity setting, and on macOS that cannot be made to behave: the call
## that moves a pointer unhooks it from the mouse underneath, and keeping it on
## the window unhooks it outright. `app/pointer.gd` has the whole finding. So
## the game keeps a pointer of its own instead, moves that at whatever speed the
## setting asks for, and takes the mouse only while the player has the controls
## — handing it back, when they let go, where its own crosshair was.
##
## What is checked here: the picture, the speed, where the pointer comes back,
## and that nothing has crept back in that drives or holds the system pointer.
##
## A window is needed: an Image would build anywhere, but a cursor is only a
## cursor once something is showing it.

var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[PTR] PASS ", what)
	else:
		fails += 1
		push_error("PTR FAIL: " + what)

## Colours come back off an 8-bit image a step away from what went in, so the
## comparison has to be within a step rather than exact.
func same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 \
		and absf(a.b - b.b) < 0.01 and absf(a.a - b.a) < 0.01

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	var was := Pointer.sensitivity
	_picture()
	_speed()
	_on_grid()
	await _in_play()
	await _handed_back()
	_hands_off()
	Pointer.set_sensitivity(was)
	print("[PTR] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _picture() -> void:
	var tex := Pointer.texture()
	check(tex != null, "the pointer is built rather than loaded")
	if tex == null:
		return
	var img := tex.get_image()
	var side: int = (Pointer.ART.size() + 2) * Pointer.SCALE
	check(img.get_width() == side and img.get_height() == side,
		"it is %d px square, art plus a pixel of edge all round (%dx%d)"
			% [side, img.get_width(), img.get_height()])

	var hot := Pointer.hotspot()
	check(same(img.get_pixel(int(hot.x), int(hot.y)), Pointer.INK),
		"the hotspot is the bright dot at the middle of the crosshair")
	check(img.get_pixel(0, 0).a == 0.0 and img.get_pixel(side - 1, side - 1).a == 0.0,
		"the corners are clear, so it is a crosshair and not a block")

	# The dark edge is the half of the drawing nothing writes down: it is worked
	# out from the body, so what is checked is that it got worked out at all.
	var inked := 0
	var edged := 0
	var clear := 0
	for y in side:
		for x in side:
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				clear += 1
			elif same(c, Pointer.INK):
				inked += 1
			elif same(c, Pointer.EDGE):
				edged += 1
	check(inked > 0 and edged > inked,
		"every bright pixel is carried by a darker edge (%d ink, %d edge)" % [inked, edged])
	check(clear > inked + edged, "and most of it is still see-through (%d clear)" % clear)
	check(Pointer._tex != null, "and the window was handed one at boot")

## How far the mouse carries the game's own pointer.
func _speed() -> void:
	var bounds := Vector2(1280, 720)
	var at := Vector2(600, 400)
	var moved := Vector2(10, -6)

	Pointer.set_sensitivity(1.0)
	check(Pointer.carry(at, moved, bounds) == at + moved,
		"at 1.0 the pointer goes exactly as far as the mouse did")
	Pointer.set_sensitivity(2.0)
	check(Pointer.carry(at, moved, bounds) == at + moved * 2.0,
		"at 2.0 it goes twice as far (%s)" % str(Pointer.carry(at, moved, bounds)))
	Pointer.set_sensitivity(0.5)
	check(Pointer.carry(at, moved, bounds) == at + moved * 0.5,
		"at 0.5 it goes half as far (%s)" % str(Pointer.carry(at, moved, bounds)))

	Pointer.set_sensitivity(2.5)
	var corner := Pointer.carry(Vector2(1275, 5), Vector2(40, -40), bounds)
	check(corner.x <= bounds.x - 1.0 and corner.y >= 0.0,
		"and it is kept on the screen it is drawn on (%s)" % str(corner))

	Pointer.set_sensitivity(99.0)
	check(Pointer.sensitivity <= Pointer.MAX_SENS,
		"the setting is held between %.1f and %.1f (%.1f)"
			% [Pointer.MIN_SENS, Pointer.MAX_SENS, Pointer.sensitivity])
	Pointer.set_sensitivity(1.7)
	Pointer.sensitivity = 1.0
	Pointer.load_saved()
	check(is_equal_approx(Pointer.sensitivity, 1.7),
		"and is written down, so the desk keeps it (%.1f)" % Pointer.sensitivity)

	# Nobody has the controls in this scene, so the system is doing the
	# pointing and the game's pointer is simply where that is.
	check(not Pointer.game_is_pointing(),
		"with nobody holding the controls, the system does the pointing")
	check(Pointer._crosshair != null and not Pointer._crosshair.visible,
		"and the game's own crosshair is not drawn over it")

## A real player holding the controls, which is the only time the setting does
## anything — and the thing that has to be checked, because a settings screen is
## never in that state. Every screen the player stands on builds one of these.
func _in_play() -> void:
	var held := Player.new()
	add_child(held)
	await frames(2)
	check(Pointer.game_is_pointing(), "with the controls held, the game does the pointing")
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"so the game takes the mouse (mode %d)" % Input.mouse_mode)
	check(Pointer._crosshair.visible, "and draws its own crosshair")

	Pointer.set_sensitivity(2.0)
	Pointer.point = Vector2(400, 300)
	var e := InputEventMouseMotion.new()
	e.relative = Vector2(30, -10)
	Pointer._input(e)
	check(Pointer.point.is_equal_approx(Vector2(460, 280)),
		"a mouse moved (30,-10) at 2.0 carries it (60,-20) (%s)" % str(Pointer.point))

	Pointer.set_sensitivity(0.5)
	Pointer.point = Vector2(400, 300)
	Pointer._input(e)
	check(Pointer.point.is_equal_approx(Vector2(415, 295)),
		"and at 0.5, half of it (%s)" % str(Pointer.point))

	await frames(2)
	check(Pointer._crosshair.position.is_equal_approx(Pointer.on_grid(Pointer.point - Pointer.hotspot())),
		"the crosshair is drawn where the game is pointing (%s)" % str(Pointer._crosshair.position))

	# And it follows the picture's grid rather than the screen's. Nothing draws
	# the world in this scene, so the slide is set by hand; in a raid the camera
	# hands one over every frame, and half of them are odd.
	var odd := Vector2(-3, -3)
	Pointer.pixel_origin = odd
	await frames(2)
	var drawn := Pointer._crosshair.position
	check(posmod(int(drawn.x - odd.x), Pointer.SCALE) == 0
			and posmod(int(drawn.y - odd.y), Pointer.SCALE) == 0,
		"and onto the odd pixels with the picture when the slide is odd (%s)" % str(drawn))
	Pointer.pixel_origin = Vector2.ZERO

	held.queue_free()
	await frames(3)
	check(not Pointer.game_is_pointing() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"and the system has its pointer back the moment the controls are let go")

## The crosshair is drawn over the picture at the picture's own scale, so it has
## to sit on the picture's grid — and that grid is not the screen's. A
## `PixelCamera` slides its image by whatever the real camera had left over, so
## the grid starts on an odd screen pixel about half the time. Snapping to the
## screen's own corner instead passed on the even half and put every art pixel
## of the crosshair across two screen ones on the odd half, which is exactly
## what `pixel_camera_test` counts.
func _on_grid() -> void:
	var s := Pointer.SCALE
	for origin: Vector2 in [Vector2.ZERO, Vector2(-2, -2), Vector2(-3, -2), Vector2(-3, -3)]:
		Pointer.pixel_origin = origin
		var on := 0
		var near := 0
		var tries := 0
		for i in 2 * s:
			for j in 2 * s:
				var at := Vector2(100.0 + float(i), 60.0 + float(j))
				var landed := Pointer.on_grid(at)
				var back := at - landed
				tries += 1
				if posmod(int(landed.x - origin.x), s) == 0 and posmod(int(landed.y - origin.y), s) == 0:
					on += 1
				# On the grid is not enough on its own — the far corner of the
				# screen is on it too. It has to be the corner `at` sits in.
				if back.x >= 0.0 and back.x < float(s) and back.y >= 0.0 and back.y < float(s):
					near += 1
		check(on == tries and near == tries,
			"with the picture's grid starting at %s, the crosshair lands on the corner it is in (%d and %d of %d)"
				% [str(origin), on, near, tries])
	Pointer.pixel_origin = Vector2.ZERO

## Letting go of the controls puts the system pointer where the crosshair was.
## Left to itself it came back in the middle of the window, where Godot parks it
## for as long as the game has the mouse, so every menu opened with a jump to the
## middle of the screen. Checked on a window that is scaled and on one that is
## letterboxed: the crosshair lives in the game's 1280x720 and the pointer in
## the window's pixels, and only the second size has an offset to get wrong.
func _handed_back() -> void:
	if not get_window().has_focus():
		# The pointer is only moved for the window in use, so with the focus
		# somewhere else there is nothing here to see.
		print("[PTR] skip the hand-back: this window does not have the focus")
		return
	var was_size := DisplayServer.window_get_size()
	for size in [Vector2i(1600, 900), Vector2i(1000, 700)]:
		DisplayServer.window_set_size(size)
		await frames(4)
		var held := Player.new()
		add_child(held)
		await frames(2)
		# Well clear of the middle, which is where it used to come back.
		var at := Vector2(260, 180)
		Pointer.point = at
		held.queue_free()
		await frames(3)
		# Within a few pixels rather than to the pixel: the system reads its
		# pointer back in whole points, two pixels each on a 2x screen, and a
		# shrunk window makes every one of those more than one of the game's.
		# The jump this is here for was four hundred.
		var back := get_viewport().get_mouse_position()
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and back.distance_to(at) < 4.0,
			"on a %dx%d window the pointer comes back where the crosshair was (%s, want %s)"
				% [size.x, size.y, str(back.round()), str(at)])
	DisplayServer.window_set_size(was_size)
	await frames(4)

## The rule the week cost: the system pointer is the system's. Nothing here
## drives it, holds it, or argues with it — it is moved once, as it is handed
## back, and that is the move `_handed_back` checks.
func _hands_off() -> void:
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"while the system is pointing, the pointer is visible and free")
	var src := FileAccess.get_file_as_string("res://app/pointer.gd")
	check(src.count("warp_mouse(") == 1,
		"the pointer is moved in one place, the hand-back, and nowhere else (%d)"
			% src.count("warp_mouse("))
	check(not src.contains("CONFINED"), "and nothing in the pointer holds it on the window")
