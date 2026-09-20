extends Node2D
## The mouse pointer the game draws for itself.
##
## The game never moves the system pointer. It drove it once, to serve a
## sensitivity setting, and on macOS that cannot be made to behave: the call
## that moves a pointer unhooks it from the mouse underneath, and keeping it on
## the window unhooks it outright. `app/pointer.gd` has the whole finding. So
## the game keeps a pointer of its own instead, moves that at whatever speed the
## setting asks for, and takes the mouse only while the player has the controls.
##
## What is checked here: the picture, the speed, and that nothing has crept back
## in that touches the system pointer.
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
	await _in_play()
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
	check(Pointer._crosshair.position.is_equal_approx(Pointer.point - Pointer.hotspot()),
		"the crosshair is drawn where the game is pointing")

	held.queue_free()
	await frames(3)
	check(not Pointer.game_is_pointing() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"and the system has its pointer back the moment the controls are let go")

## The rule the week cost: the system pointer is the system's. Nothing here
## moves it, holds it, or argues with it.
func _hands_off() -> void:
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"while the system is pointing, the pointer is visible and free")
	var src := FileAccess.get_file_as_string("res://app/pointer.gd")
	check(not src.contains("warp_mouse"), "nothing in the pointer moves it")
	check(not src.contains("CONFINED"), "and nothing in the pointer holds it on the window")
