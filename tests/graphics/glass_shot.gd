extends Node
## Frames of glass, for looking at: the Moonlit Grove map on the creator's
## table with a floor of mirror laid under the lintel, a pillar of clear glass
## standing on it, a mirror on the back wall behind it, and a stretch of ruin
## wall with a window of clear glass in it; the map played, with the body on
## the floor in front of the back mirror and then up against the pillar; each
## close up; and where the glass is, as the glazing's marks have it — clear
## glass blue, a mirror across its faces red, the brighter the further the
## pixel it shows, and a back mirror green.
##
## Needs a real renderer — `--headless` draws into a dummy and saves black.
## Writes to `user://shots` unless SHOTS_DIR names somewhere else. With
## HIDE_WINDOW set the window is put away as soon as it opens, and every frame
## is drawn by hand. It saves no map, and leaves the profile as it is.

const GameScript := preload("res://app/game.gd")
var dir: String = "user://shots"

## One frame. A window that is put away, or that something covers, is not
## drawn at all, so while that lasts the frame is drawn here instead.
func tick() -> void:
	await get_tree().process_frame
	if not DisplayServer.window_can_draw() or OS.has_environment("HIDE_WINDOW"):
		RenderingServer.force_draw(false)

func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await tick()
		t += get_process_delta_time()

func save(img: Image, shot_name: String, times: int = 1) -> void:
	if times > 1:
		img.resize(img.get_width() * times, img.get_height() * times, Image.INTERPOLATE_NEAREST)
	var err := img.save_png(dir.path_join(shot_name + ".png"))
	print("[SHOT] ", shot_name, " -> ", dir, "" if err == OK else " FAILED (%d)" % err)

## The screen, or `crop` of it two times the size.
func shot(shot_name: String, crop: Rect2i = Rect2i()) -> void:
	await tick()
	var img := get_viewport().get_texture().get_image()
	if crop.size != Vector2i.ZERO:
		save(img.get_region(crop), shot_name, 2)
	else:
		save(img, shot_name)

## The marks, twice the size: clear glass blue, a mirror red, each brighter the
## further off what it shows.
func marks_shot(shot_name: String, glazing: Glazing) -> void:
	await tick()
	var marks := glazing.marks().get_image()
	var out := Image.create_empty(marks.get_width(), marks.get_height(), false, Image.FORMAT_RGBA8)
	for y in marks.get_height():
		for x in marks.get_width():
			var m := marks.get_pixel(x, y)
			if absf(m.b) < 128.0:
				out.set_pixel(x, y, Color.BLACK)
			elif m.b > 0.0 and absf(m.r) + absf(m.g) > 0.5:
				out.set_pixel(x, y, Color(0.3, 0.85, 0.4))
			elif m.b > 0.0:
				out.set_pixel(x, y, Color(0.2, 0.6, 1.0))
			else:
				var far := clampf(Vector2(m.r, m.g).length() / 16.0 / 64.0, 0.0, 1.0)
				out.set_pixel(x, y, Color(0.35 + 0.65 * far, 0.15, 0.2))
	save(out, shot_name, 2)

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	if OS.has_environment("HIDE_WINDOW"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	if OS.has_environment("SHOTS_DIR"):
		dir = OS.get_environment("SHOTS_DIR")
	DirAccess.make_dir_recursive_absolute(dir)
	MapMaker.forget()
	var game := Node.new()
	game.set_script(GameScript)
	add_child(game)
	await wait(0.1)
	game.goto_map_maker()
	await wait(0.1)
	var maker := game.current as MapMaker
	var table := (Views.of(maker) as MapMakerView).table
	table._load("moonlit_grove")
	maker.begin_stroke()
	# A floor of mirror under the lintel, two cells deep, and a pillar of clear
	# glass standing on it.
	for x in range(11, 31):
		maker.lay(Vector2i(x, 20), "@")
		maker.lay(Vector2i(x, 21), "@")
	for y in range(14, 20):
		maker.lay(Vector2i(28, y), "o")
		maker.lay(Vector2i(29, y), "o")
	# A mirror on the back wall under the lintel, down to the floor; and a
	# stretch of ruin wall to the left with a window of clear glass in it.
	for y in range(11, 20):
		for x in range(20, 24):
			maker.lay(Vector2i(x, y), "@", MapMaker.BACK)
	for y in range(6, 14):
		for x in range(2, 9):
			maker.lay(Vector2i(x, y), "o" if x >= 4 and x < 7 and y >= 8 and y < 12 else "#", MapMaker.BACK)
	table._changed_all()
	table.take_tab(MapTable.Tab.GROUND)
	await wait(0.3)
	await shot("70_glass_table")
	maker.play()
	await wait(1.0)
	var pixels := (Views.of(maker) as MapMakerView).pixels
	maker.player.global_position = Vector2(21.5, 19.5) * Room.CELL
	await wait(1.0)
	await shot("71_glass_played")
	await shot("72_mirror_close", Rect2i(520, 520, 400, 200))
	await marks_shot("73_glass_marks", pixels.glazing)
	maker.player.global_position = Vector2(26.6, 19.5) * Room.CELL
	await wait(0.6)
	await shot("74_clear_close", Rect2i(700, 380, 340, 300))
	maker.player.global_position = Vector2(21.0, 19.5) * Room.CELL
	await wait(0.6)
	await shot("75_back_mirror_close", Rect2i(560, 300, 300, 360))
	await shot("76_window_close", Rect2i(40, 180, 300, 300))
	maker.stop()
	await wait(0.2)
	get_tree().quit()
