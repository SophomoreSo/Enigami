extends Node2D
## The mouse pointer: the picture the game draws for it, and the setting that
## decides how far it moves.
##
## A window is needed for both halves. The picture is built from an Image, which
## would work anywhere, but the interesting half is the arithmetic that turns a
## place on the 1280x720 the game is drawn at into a place in whatever size the
## window happens to be — and a window is the only thing that can say whether
## that came out right.

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
	# The setting and the pointer both belong to whoever is at this desk. Both
	# go back the way they were found.
	var was := Pointer.sensitivity
	var was_at := DisplayServer.mouse_get_position()
	_picture()
	_setting()
	await _window()
	await _wiring()
	await _where_it_lives()
	Pointer.set_sensitivity(was)
	DisplayServer.warp_mouse(was_at)
	print("[PTR] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- what it looks like -----------------------------------------------------
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

## --- how far it moves -------------------------------------------------------
func _setting() -> void:
	var at := Vector2(600, 400)
	var moved := Vector2(10, -6)

	Pointer.set_sensitivity(1.0)
	check(Pointer.target_for(at, moved) == at,
		"at 1.0 the pointer is left exactly where the mouse put it")

	Pointer.set_sensitivity(2.0)
	check(Pointer.target_for(at, moved) == at + moved,
		"at 2.0 it is carried the same distance again (%s)"
			% str(Pointer.target_for(at, moved)))

	Pointer.set_sensitivity(0.5)
	check(Pointer.target_for(at, moved) == at - moved * 0.5,
		"at 0.5 it is pulled back half of what the hand did (%s)"
			% str(Pointer.target_for(at, moved)))

	Pointer.set_sensitivity(99.0)
	check(Pointer.sensitivity <= Pointer.MAX_SENS,
		"the setting is held between %.1f and %.1f (%.1f)"
			% [Pointer.MIN_SENS, Pointer.MAX_SENS, Pointer.sensitivity])
	Pointer.set_sensitivity(0.0)
	check(Pointer.sensitivity >= Pointer.MIN_SENS, "at both ends (%.1f)" % Pointer.sensitivity)

	# It outlives the run that set it.
	Pointer.set_sensitivity(1.6)
	Pointer.sensitivity = 1.0
	Pointer.load_saved()
	check(is_equal_approx(Pointer.sensitivity, 1.6),
		"and is written down, so the desk keeps it (%.1f)" % Pointer.sensitivity)

## --- the window -------------------------------------------------------------
func _window() -> void:
	var win := get_window()
	var was_size := win.size
	var view := Vector2(get_viewport().get_visible_rect().size)

	# The game is drawn at one size into a window of another, so a place in the
	# first has to be turned into a place in the second before the pointer can
	# be put there. This is that conversion, checked on a window deliberately
	# the wrong size for it.
	win.size = Vector2i(int(view.x) + 320, int(view.y) + 180)
	await frames(3)
	var to_window := win.get_final_transform()
	var far: Vector2 = to_window * view
	check(far.distance_to(Vector2(win.size)) < 8.0,
		"the far corner of the game lands on the far corner of the window (%s of %s)"
			% [str(far.round()), str(win.size)])
	check((to_window * Vector2.ZERO).length() < 8.0, "and the near corner on the near one")

	# And the pointer actually goes where it is sent. The desk's own pointer is
	# put back where it was found.
	var want := Vector2(int(view.x * 0.5), int(view.y * 0.5))
	Input.warp_mouse(to_window * want)
	await frames(3)
	var landed := get_viewport().get_mouse_position()
	check(landed.distance_to(want) < 6.0,
		"a pointer sent to %s arrives at %s" % [str(want), str(landed.round())])
	win.size = was_size
	await frames(2)

## --- the wiring -------------------------------------------------------------
## The one link the pieces above do not cover on their own: that the pointer is
## in the tree, hears the mouse and carries it the extra distance.
func _wiring() -> void:
	check(Pointer._tex != null, "the pointer was handed to the window at boot")
	Pointer.set_sensitivity(2.0)
	var start := Vector2(400, 300)
	Input.warp_mouse(start)
	await frames(2)
	var moved := Vector2(40, 0)
	var e := InputEventMouseMotion.new()
	e.position = start + moved
	e.relative = moved
	Input.parse_input_event(e)
	await frames(3)
	var now := get_viewport().get_mouse_position()
	check(now.x > start.x + moved.x * 1.5,
		"a mouse moved %.0f px at 2.0 carries the pointer about twice that (%s)"
			% [moved.x, str(now.round())])

	# And at 1.0 the game does not touch the pointer at all. A parsed event says
	# the mouse moved without the desk's pointer having gone anywhere, so what
	# is being watched here is whether the game moves it — and at 1.0 it must
	# not, which is what the game ships at.
	Pointer.set_sensitivity(1.0)
	Input.warp_mouse(start)
	await frames(2)
	var quiet := InputEventMouseMotion.new()
	quiet.position = start + moved
	quiet.relative = moved
	Input.parse_input_event(quiet)
	await frames(3)
	check(get_viewport().get_mouse_position().distance_to(start) < 6.0,
		"and at 1.0 it leaves the pointer exactly where the mouse had it (%s)"
			% str(get_viewport().get_mouse_position().round()))

	# On the way out of the window the extra distance is dropped, so nothing
	# holds the pointer against the border: the desk gets it back.
	var view := Vector2(get_viewport().get_visible_rect().size)
	var edge := Vector2(view.x - 12.0, view.y * 0.5)
	Pointer.set_sensitivity(2.5)
	Input.warp_mouse(edge)
	await frames(2)
	var out := InputEventMouseMotion.new()
	out.position = edge + Vector2(8, 0)
	out.relative = Vector2(8, 0)
	Input.parse_input_event(out)
	await frames(3)
	check(get_viewport().get_mouse_position().distance_to(edge) < 6.0,
		"a move that would carry the pointer off the window is not helped along (%s)"
			% str(get_viewport().get_mouse_position().round()))
	check(not get_viewport().get_visible_rect().has_point(
			Pointer.target_for(edge + Vector2(8, 0), Vector2(8, 0))),
		"because where it would have gone is off the edge (%s)"
			% str(Pointer.target_for(edge + Vector2(8, 0), Vector2(8, 0))))

	# And a pointer already gone is not fetched back, which is what a setting
	# below 1.0 would otherwise do with it.
	Pointer.set_sensitivity(0.4)
	Input.warp_mouse(edge)
	await frames(2)
	var gone := InputEventMouseMotion.new()
	gone.position = Vector2(view.x + 30.0, view.y * 0.5)
	gone.relative = Vector2(40, 0)
	Input.parse_input_event(gone)
	await frames(3)
	check(get_viewport().get_mouse_position().distance_to(edge) < 6.0,
		"a pointer that has left the window is left alone (%s)"
			% str(get_viewport().get_mouse_position().round()))

## --- where the setting lives ------------------------------------------------
## On the control settings page, in both screens that have one: it is a control,
## and a player looking for it will look where the keys are.
func _where_it_lives() -> void:
	var panel := ControlsPanel.new()
	panel.pixel = true
	add_child(panel)
	await frames(2)
	var found: HSlider = null
	for node in _all_under(panel):
		if node is HSlider:
			found = node as HSlider
	check(found != null, "the controls panel carries the pointer's own slider")
	if found == null:
		return
	check(is_equal_approx(found.min_value, Pointer.MIN_SENS)
			and is_equal_approx(found.max_value, Pointer.MAX_SENS),
		"set to the range the pointer allows (%.1f to %.1f)" % [found.min_value, found.max_value])
	check(is_equal_approx(found.value, Pointer.sensitivity),
		"and showing what the pointer is set to (%.1f)" % found.value)
	found.value = Pointer.MIN_SENS
	await frames(2)
	check(is_equal_approx(Pointer.sensitivity, Pointer.MIN_SENS),
		"moving it moves the pointer's own setting (%.1f)" % Pointer.sensitivity)
	panel.queue_free()
	await frames(2)

func _all_under(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all_under(c))
	return out
