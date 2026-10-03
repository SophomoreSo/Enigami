extends Node
## The hideout's looks, and the page that picks one (`HideoutThemes`,
## `ThemePicker`, and HIDEOUT THEME on the pause menu) — there while the
## hideout's look is being chosen.
##
## Every look has a name, in every language. With nothing kept, a room wears
## the one it starts in. PAUSED has a door to the page in the hideout and
## nowhere else. The page hangs in the corner of the screen with the shade
## cleared, so the room is in sight behind it; it lists every look, with the
## one in force lit and unpressable. Pressing another dresses the room in it
## there and then — the game is stopped, and the picture behind the page is
## another picture all the same, and goes on moving — rebuilds the list round
## the new answer, and keeps it in its file, so the next room walked into wears
## it too. A look put on by anything else is the one the list shows, and one
## only tried on is not kept. The pause key goes back one level at a time. And in mobile mode the
## page is a thumb's: it takes the screen, under the shade every page has.
##
## Needs a real renderer: what shows behind the page is read off the frame.

const GameScript := preload("res://app/game.gd")

var game: Node
var world: HideoutWorld
var view: HideoutWorldView
var fails := 0
var _drawn := false

func check(ok: bool, what: String) -> void:
	if ok:
		print("[THEME] PASS ", what)
	else:
		fails += 1
		push_error("THEME FAIL: " + what)

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

func press(action: String) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		Input.parse_input_event(e)
		await wait(0.08)
	await wait(0.1)

func screen() -> Vector2:
	return get_viewport().get_visible_rect().size

## A look's button on the page, as it is now: the list is built again at
## every pick.
func button(id: String) -> Button:
	return game.pause_looks.find_child(ThemePicker.button_name(id), true, false) as Button

## The look the file says is kept, or "" with no file.
func kept() -> String:
	if not FileAccess.file_exists(HideoutThemes.PATH):
		return ""
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(HideoutThemes.PATH))
	return String((parsed as Dictionary).get("look", "")) if parsed is Dictionary else ""

func _ready() -> void:
	# The page stops the game, and this has to go on running behind it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	RenderingServer.frame_post_draw.connect(func() -> void: _drawn = true)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	GameState.reset_profile()
	# The machine is put back as it was found: its pick, its language, its mode.
	var had := FileAccess.file_exists(HideoutThemes.PATH)
	var was := FileAccess.get_file_as_string(HideoutThemes.PATH) if had else ""
	var was_language := Loc.language
	var was_mode := Touch.mode
	Touch.set_mode(Touch.OFF)
	if had:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(HideoutThemes.PATH))
	HideoutThemes.reread()

	_the_names()
	Loc.set_language(was_language)
	check(HideoutThemes.picked() == HideoutThemes.DEFAULT,
		"with nothing kept, a room wears the look it starts in (%s)" % HideoutThemes.picked())
	HideoutThemes.pick("no such look")
	check(HideoutThemes.picked() == HideoutThemes.DEFAULT and kept() == "", "a look nobody has heard of is refused")

	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await wait(0.2)
	await _the_door()
	await _the_page()
	await _picking()
	_tried_on()
	await _the_way_back()
	await _kept_for_next_time()
	await _for_a_thumb()

	if get_tree().paused:
		game._unpause()
	Touch.set_mode(was_mode)
	Loc.set_language(was_language)
	HideoutThemes.pick(HideoutThemes.DEFAULT, false)
	if had:
		var f := FileAccess.open(HideoutThemes.PATH, FileAccess.WRITE)
		f.store_string(was)
		f.close()
	elif FileAccess.file_exists(HideoutThemes.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(HideoutThemes.PATH))
	HideoutThemes.reread()
	print("[THEME] ---- %d failures ----" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## --- what they are called ---------------------------------------------------

func _the_names() -> void:
	for lang in Loc.languages():
		Loc.set_language(lang)
		var names: Array = []
		var named := true
		for id: String in HideoutThemes.LOOKS:
			var key := "hideout.theme.look.%s" % id
			var called := HideoutThemes.name_for(id)
			if not Loc.has(key) or called == "" or called == key or names.has(called):
				named = false
			names.append(called)
		check(named, "in %s every look has a name of its own (%s)" % [lang, ", ".join(names)])
		check(Loc.has("hideout.theme.heading") and Loc.has("hideout.theme.note"),
			"and the page has its heading and the line under it in %s" % lang)

## --- the door ---------------------------------------------------------------

func _enter_hideout() -> void:
	game.goto_hideout()
	world = game.current
	await settle(func() -> bool: return Views.of(world) != null and (Views.of(world) as HideoutWorldView).scenery != null)
	view = Views.of(world)

func _the_door() -> void:
	game.goto_sandbox()
	await wait(0.3)
	game._pause()
	await wait(0.15)
	check(not game.pause_looks_door.is_visible_in_tree(), "at the bench, PAUSED has no door to the looks")
	game._unpause()
	await _enter_hideout()
	check(view.scenery.look == HideoutThemes.DEFAULT, "the hideout's room is dressed in the look it starts in")
	game._pause()
	await wait(0.15)
	var door: Button = game.pause_looks_door
	check(door.is_visible_in_tree() and door.text == Loc.t("hideout.theme.heading"),
		"in the hideout it has one, and it says where it goes (%s)" % door.text)
	check(Rect2(Vector2.ZERO, screen()).encloses(door.get_global_rect())
			and door.get_global_rect().position.y > (game.pause_main as Control).get_global_rect().position.y,
		"on PAUSED, on the screen")

## --- the page ---------------------------------------------------------------

func _the_page() -> void:
	game.pause_looks_door.pressed.emit()
	await wait(0.15)
	check(game.pause_looks.visible and not game.pause_main.visible and get_tree().paused,
		"the door opens the looks' page in PAUSED's place, the game still stopped")
	check(game.pause_shade.color.a == 0.0, "with the shade cleared, so the room is in sight behind it")
	var page := (game.pause_looks as Control).get_global_rect()
	check(page.position.x <= 40.0 and page.position.y <= 40.0 and Rect2(Vector2.ZERO, screen()).encloses(page)
			and page.end.x <= screen().x * 0.4,
		"it hangs in the top-left corner, clear of most of the room (%s)" % str(page))
	var listed := 0
	var said := true
	for id: String in HideoutThemes.LOOKS:
		var b := button(id)
		if b != null and b.is_visible_in_tree():
			listed += 1
			if b.text != HideoutThemes.name_for(id) or not page.encloses(b.get_global_rect()):
				said = false
	check(listed == HideoutThemes.LOOKS.size() and said,
		"and lists every look by name, on the page (%d of %d)" % [listed, HideoutThemes.LOOKS.size()])
	check(_in_force() == [HideoutThemes.DEFAULT], "the one in force is the one that cannot be pressed (%s)" % str(_in_force()))

## The looks whose buttons are unpressable.
func _in_force() -> Array:
	var out: Array = []
	for id: String in HideoutThemes.LOOKS:
		var b := button(id)
		if b != null and b.disabled:
			out.append(id)
	return out

## --- picking ----------------------------------------------------------------

func _picking() -> void:
	# Each look in turn, and back to the first.
	var turns: Array = HideoutThemes.LOOKS.slice(1) + [HideoutThemes.LOOKS[0]]
	var page := Rect2i((game.pause_looks as Control).get_global_rect())
	for id: String in turns:
		var before := await frame()
		var old := view.scenery
		button(id).pressed.emit()
		check(view.scenery != old and view.scenery.look == id and get_tree().paused,
			"%s: pressed, the room is dressed in it there and then, the game still stopped" % id)
		check(_in_force() == [id], "%s: and the list is built again round it (%s)" % [id, str(_in_force())])
		check(kept() == id, "%s: it is kept in its file (%s)" % [id, kept()])
		await wait(0.3)
		var after := await frame()
		var changed := 0
		for y in range(0, after.get_height(), 4):
			for x in range(0, after.get_width(), 4):
				if not page.has_point(Vector2i(x, y)) and before.get_pixel(x, y) != after.get_pixel(x, y):
					changed += 1
		check(changed > 8000, "%s: the picture behind the page is another picture (%d of its pixels)" % [id, changed])
		var moving: HideoutScenery.Layer = view.scenery._moving[0]
		var painted := moving.painted
		await wait(0.4)
		check(moving.painted > painted, "%s: and goes on moving behind it (%d more times drawn)"
			% [id, moving.painted - painted])
		var onto := get_viewport().get_final_transform() * get_viewport().get_canvas_transform() * view.global_transform
		var gate := view._plate(world.stations["gate"] as Station)
		var ground := (await frame()).get_pixelv(Vector2i(onto * (gate.position + Vector2(6.0, 6.0))))
		var plate := view.scenery.plate
		check(absf(ground.r - plate.r) < 0.02 and absf(ground.g - plate.g) < 0.02 and absf(ground.b - plate.b) < 0.02,
			"%s: with the stations' signs in its colours" % id)

## A look put on by something other than the list — a test trying one on,
## which keeps nothing — is still the one the list shows.
func _tried_on() -> void:
	var first: String = HideoutThemes.LOOKS[0]
	var other: String = HideoutThemes.LOOKS[1]
	HideoutThemes.pick(other, false)
	check(view.scenery.look == other and _in_force() == [other],
		"a look put on by anything else is the one the list shows in force (%s)" % str(_in_force()))
	check(kept() == first, "and one only tried on is not kept: the file still says %s" % kept())
	HideoutThemes.pick(first, false)
	check(_in_force() == [first], "and taken off again, the list is back as it was")

## --- the way back -----------------------------------------------------------

func _the_way_back() -> void:
	await press("pause")
	check(game.pause_main.visible and not game.pause_looks.visible and get_tree().paused,
		"the pause key on the page goes back to PAUSED, not into the game")
	check(game.pause_shade.color == UiKit.SHADE, "and the shade is back under it")
	game._pause_looks(true)
	await wait(0.1)
	var back: Button = null
	for b in game.pause_looks.find_children("*", "Button", true, false):
		if (b as Button).text == Menus.text_for("general", "back"):
			back = b
	check(back != null and back.is_visible_in_tree(), "the page has its way back along the foot (%s)"
		% Menus.text_for("general", "back"))
	if back != null:
		back.pressed.emit()
		await wait(0.1)
		check(game.pause_main.visible and not game.pause_looks.visible, "which goes back to PAUSED too")
	await press("pause")
	check(not get_tree().paused and not game.pause_menu.visible, "and from PAUSED the key goes back into the game")

## --- the pick, kept ---------------------------------------------------------

func _kept_for_next_time() -> void:
	var other: String = HideoutThemes.LOOKS[1]
	game._pause()
	game._pause_looks(true)
	await wait(0.1)
	button(other).pressed.emit()
	game._unpause()
	await wait(0.1)
	# Another room, and the page left behind with the one before it.
	await _enter_hideout()
	check(view.scenery.look == other, "a hideout walked into afterwards is dressed in what was picked (%s)"
		% view.scenery.look)
	HideoutThemes.reread()
	check(HideoutThemes.picked() == other and kept() == other, "and read again from its file, the pick is the same")
	game._pause()
	await wait(0.1)
	check(game.pause_main.visible and not game.pause_looks.visible and game.pause_shade.color == UiKit.SHADE,
		"paused again, the menu comes up on PAUSED, under its shade")
	game._pause_looks(true)
	await wait(0.1)
	button(HideoutThemes.DEFAULT).pressed.emit()
	check(view.scenery.look == HideoutThemes.DEFAULT, "and a pick made over the new room dresses the new room")
	game._unpause()
	await wait(0.1)

## --- for a thumb ------------------------------------------------------------

func _for_a_thumb() -> void:
	Touch.set_mode(Touch.ON)
	game._pause()
	await wait(0.2)
	game._pause_looks(true)
	await wait(0.2)
	var looks := game.pause_looks as UiKit.ScreenFrame
	check(looks.thumb and looks.visible, "in mobile mode the page is built for a thumb")
	var page := looks.get_global_rect()
	check(absf(page.get_center().x - screen().x * 0.5) < 2.0 and page.size.x > screen().x * 0.6
			and Rect2(Vector2.ZERO, screen()).encloses(page),
		"which takes the middle of the screen (%s)" % str(page))
	check(game.pause_shade.color == UiKit.SHADE, "under the shade every page has: there is no room left to see")
	var tall := true
	for id: String in HideoutThemes.LOOKS:
		if button(id) == null or button(id).size.y < UiKit.THUMB - 0.5:
			tall = false
	check(tall, "with every look a thumb tall")
	var other: String = HideoutThemes.LOOKS[HideoutThemes.LOOKS.size() - 1]
	button(other).pressed.emit()
	check(view.scenery.look == other and _in_force() == [other], "and a look pressed there is put on just the same")
	button(HideoutThemes.DEFAULT).pressed.emit()
	game._unpause()
	Touch.set_mode(Touch.OFF)
	await wait(0.2)
